/* Local WebSocket smoke client, linked to the installed libcurl-impersonate. */
#include <stdio.h>
#include <string.h>
#include <poll.h>

#include <curl/curl.h>

static int wait_socket(CURL *curl, short events)
{
    curl_socket_t socket;
    struct pollfd fd;
    if(curl_easy_getinfo(curl, CURLINFO_ACTIVESOCKET, &socket) != CURLE_OK ||
       socket == CURL_SOCKET_BAD)
        return 1;
    fd.fd = socket;
    fd.events = events;
    fd.revents = 0;
    if(poll(&fd, 1, 5000) <= 0) {
        fprintf(stderr, "WebSocket socket wait failed or timed out\n");
        return 1;
    }
    return 0;
}

static int roundtrip(CURL *curl, const unsigned char *payload, size_t length,
                     unsigned int send_flags, int recv_flags)
{
    size_t offset = 0;
    CURLcode result;
    do {
        size_t sent = 0;
        result = curl_ws_send(curl, payload + offset, length - offset,
                              &sent, 0, send_flags);
        if(result != CURLE_OK && result != CURLE_AGAIN) {
            fprintf(stderr, "curl_ws_send: %s\n", curl_easy_strerror(result));
            return 1;
        }
        offset += sent;
        if(result == CURLE_AGAIN && wait_socket(curl, POLLOUT))
            return 1;
    } while(offset < length || result == CURLE_AGAIN);

    offset = 0;
    for(;;) {
        /* Deliberately consume larger messages in multiple chunks. */
        unsigned char buffer[127];
        size_t received = 0;
        const struct curl_ws_frame *meta;
        result = curl_ws_recv(curl, buffer, sizeof(buffer), &received, &meta);
        if(result == CURLE_AGAIN) {
            if(wait_socket(curl, POLLIN))
                return 1;
            continue;
        }
        if(result != CURLE_OK) {
            fprintf(stderr, "curl_ws_recv: %s\n", curl_easy_strerror(result));
            return 1;
        }
        if(meta->flags != recv_flags || meta->offset != (curl_off_t)offset ||
           offset + received > length ||
           memcmp(buffer, payload + offset, received)) {
            fprintf(stderr, "Unexpected frame metadata or payload (flags=%d)\n",
                    meta->flags);
            return 1;
        }
        offset += received;
        if(!meta->bytesleft)
            break;
    }
    if(offset != length) {
        fprintf(stderr, "Truncated WebSocket payload: %zu of %zu bytes\n",
                offset, length);
        return 1;
    }
    return 0;
}

#define CHECK(call) do { \
    result = (call); \
    if(result != CURLE_OK) { \
        fprintf(stderr, "%s: %s (%s)\n", #call, \
                curl_easy_strerror(result), error); \
        goto cleanup; \
    } \
} while(0)

int main(int argc, char **argv)
{
    CURL *curl;
    CURLcode result;
    int status = 1;
    long response = 0;
    char error[CURL_ERROR_SIZE] = {0};
    const unsigned char text[] = "WebSocket smoke: hello!";
    const unsigned char ping[] = "ping";
    const unsigned char close[] = {0x03, 0xe8}; /* Normal closure, 1000. */
    unsigned char binary[513];
    size_t i;
    int deflate;
    int repeat;

    if((argc != 3 && argc != 4) ||
       (argc == 4 && strcmp(argv[3], "--deflate"))) {
        fprintf(stderr, "Usage: %s URL PROFILE (or none) [--deflate]\n", argv[0]);
        return 1;
    }
    deflate = argc == 4;
    if(curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK)
        return 1;
    curl = curl_easy_init();
    if(!curl) {
        curl_global_cleanup();
        return 1;
    }
    CHECK(curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, error));
    if(strcmp(argv[2], "none"))
        CHECK(curl_easy_impersonate(curl, argv[2], 1));
    if(deflate)
        CHECK(curl_easy_setopt(curl, CURLOPT_WS_OPTIONS,
                               CURLWS_PERMESSAGE_DEFLATE));
    CHECK(curl_easy_setopt(curl, CURLOPT_URL, argv[1]));
    CHECK(curl_easy_setopt(curl, CURLOPT_CONNECT_ONLY, 2L));
    CHECK(curl_easy_setopt(curl, CURLOPT_TIMEOUT, 5L));
    CHECK(curl_easy_setopt(curl, CURLOPT_NOPROXY, "*"));
    /* The loopback server uses the existing self-signed test certificate. */
    CHECK(curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L));
    CHECK(curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L));
    CHECK(curl_easy_perform(curl));
    CHECK(curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response));
    if(response != 101) {
        fprintf(stderr, "Expected HTTP 101 upgrade, got %ld\n", response);
        goto cleanup;
    }

    for(i = 0; i < sizeof(binary); ++i)
        binary[i] = (unsigned char)i;
    /* Repeated compressed messages also exercise context takeover. */
    for(repeat = 0; repeat < (deflate ? 2 : 1); ++repeat) {
        if(roundtrip(curl, text, sizeof(text) - 1, CURLWS_TEXT, CURLWS_TEXT) ||
           roundtrip(curl, binary, sizeof(binary), CURLWS_BINARY, CURLWS_BINARY))
            goto cleanup;
    }
    if(roundtrip(curl, ping, sizeof(ping) - 1, CURLWS_PING, CURLWS_PONG) ||
       roundtrip(curl, close, sizeof(close), CURLWS_CLOSE, CURLWS_CLOSE))
        goto cleanup;
    status = 0;

cleanup:
    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return status;
}
