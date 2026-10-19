#include <curl/curl.h>

int main(void)
{
    CURL *curl;
    CURLcode result = curl_global_init(CURL_GLOBAL_ALL);
    if(result != CURLE_OK)
        return (int)result;
    curl = curl_easy_init();
    if(!curl) {
        curl_global_cleanup();
        return CURLE_FAILED_INIT;
    }
    /* Require curl-impersonate's headers and exported API. */
    result = curl_easy_impersonate(curl, "chrome150", 0);
    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return (int)result;
}
