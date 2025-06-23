# DefaultAPI

All URIs are relative to *https://visionchess.xreco-retrieval.ch*

Method | HTTP request | Description
------------- | ------------- | -------------
[**usersAuthLogoutPost**](DefaultAPI.md#usersauthlogoutpost) | **POST** /users/auth/logout | 


# **usersAuthLogoutPost**
```swift
    open class func usersAuthLogoutPost(logoutRequest: LogoutRequest, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```



Handles user logout by invalidating the active session.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let logoutRequest = LogoutRequest(id: "id_example") // LogoutRequest | 

DefaultAPI.usersAuthLogoutPost(logoutRequest: logoutRequest) { (response, error) in
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

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **logoutRequest** | [**LogoutRequest**](LogoutRequest.md) |  | 

### Return type

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

