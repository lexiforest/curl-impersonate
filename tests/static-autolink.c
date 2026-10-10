#include <stdio.h>
#include <curl/curl.h>

int main(int argc, char **argv)
{
    CURLcode result;
    CURL *curl;

    if (argc != 2) {
        return 2;
    }
    result = curl_global_init(CURL_GLOBAL_ALL);
    if (result != CURLE_OK) {
        return (int)result;
    }
    curl = curl_easy_init();
    if (!curl) {
        curl_global_cleanup();
        return CURLE_FAILED_INIT;
    }
    /* Require the release headers rather than silently using system libcurl. */
    result = curl_easy_impersonate(curl, "chrome150", 0);
    if (result == CURLE_OK) {
        result = curl_easy_setopt(curl, CURLOPT_URL, argv[1]);
    }
    if (result == CURLE_OK) {
        result = curl_easy_setopt(curl, CURLOPT_WRITEDATA, stdout);
    }
    if (result == CURLE_OK) {
        result = curl_easy_perform(curl);
    }
    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return (int)result;
}
