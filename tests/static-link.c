#include <curl/curl.h>
#include <stdio.h>

int main(void)
{
    CURLcode result = curl_global_init(CURL_GLOBAL_ALL);
    if(result != CURLE_OK) {
        fprintf(stderr, "curl_global_init: %s\n", curl_easy_strerror(result));
        return 1;
    }
    CURL *curl = curl_easy_init();
    if(!curl) {
        fprintf(stderr, "curl_easy_init failed\n");
        curl_global_cleanup();
        return 1;
    }
    printf("%s\n", curl_version());
    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return 0;
}
