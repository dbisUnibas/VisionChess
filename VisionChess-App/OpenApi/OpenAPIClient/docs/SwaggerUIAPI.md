# SwaggerUIAPI

All URIs are relative to *https://visionchess.xreco-retrieval.ch*

Method | HTTP request | Description
------------- | ------------- | -------------
[**rootGet**](SwaggerUIAPI.md#rootget) | **GET** / | 


# **rootGet**
```swift
    open class func rootGet(completion: @escaping (_ data: Void?, _ error: Error?) -> Void)
```





### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient


SwaggerUIAPI.rootGet() { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

Void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

