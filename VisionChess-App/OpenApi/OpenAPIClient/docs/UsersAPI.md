# UsersAPI

All URIs are relative to *https://visionchess.xreco-retrieval.ch*

Method | HTTP request | Description
------------- | ------------- | -------------
[**usersAuthLoginPost**](UsersAPI.md#usersauthloginpost) | **POST** /users/auth/login | 
[**usersAuthProfileGet**](UsersAPI.md#usersauthprofileget) | **GET** /users/auth/profile | 
[**usersEmailGet**](UsersAPI.md#usersemailget) | **GET** /users/{email} | 
[**usersGet**](UsersAPI.md#usersget) | **GET** /users | 
[**usersIdDelete**](UsersAPI.md#usersiddelete) | **DELETE** /users/{id} | 
[**usersIdPasswordPatch**](UsersAPI.md#usersidpasswordpatch) | **PATCH** /users/{id}/password | 
[**usersIdPatch**](UsersAPI.md#usersidpatch) | **PATCH** /users/{id} | 
[**usersPost**](UsersAPI.md#userspost) | **POST** /users | 


# **usersAuthLoginPost**
```swift
    open class func usersAuthLoginPost(loginRequest: LoginRequest, completion: @escaping (_ data: LoginResponse?, _ error: Error?) -> Void)
```



Handles user login, verifies credentials, and generates a JWT token.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let loginRequest = LoginRequest(email: "email_example", password: "password_example") // LoginRequest | 

UsersAPI.usersAuthLoginPost(loginRequest: loginRequest) { (response, error) in
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
 **loginRequest** | [**LoginRequest**](LoginRequest.md) |  | 

### Return type

[**LoginResponse**](LoginResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **usersAuthProfileGet**
```swift
    open class func usersAuthProfileGet(completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```



Retrieves the authenticated user's profile and renews the token if expired.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient


UsersAPI.usersAuthProfileGet() { (response, error) in
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

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **usersEmailGet**
```swift
    open class func usersEmailGet(email: String, completion: @escaping (_ data: String?, _ error: Error?) -> Void)
```



Retrieves a user by email.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let email = "email_example" // String | 

UsersAPI.usersEmailGet(email: email) { (response, error) in
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
 **email** | **String** |  | 

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain, */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **usersGet**
```swift
    open class func usersGet(completion: @escaping (_ data: [UserResponse]?, _ error: Error?) -> Void)
```



Retrieves all users.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient


UsersAPI.usersGet() { (response, error) in
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

[**[UserResponse]**](UserResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **usersIdDelete**
```swift
    open class func usersIdDelete(id: String, completion: @escaping (_ data: String?, _ error: Error?) -> Void)
```



Deletes a user by ID.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = "id_example" // String | 

UsersAPI.usersIdDelete(id: id) { (response, error) in
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
 **id** | **String** |  | 

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **usersIdPasswordPatch**
```swift
    open class func usersIdPasswordPatch(id: String, user: User, completion: @escaping (_ data: String?, _ error: Error?) -> Void)
```



Updates a user's password by ID.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = "id_example" // String | 
let user = User(id: ObjectId(timestamp: 123), email: "email_example", password: "password_example", lastLogin: Date(), activeSessions: [UserSession(token: "token_example", CSRF: "CSRF_example", validTo: Date())], role: "role_example") // User | 

UsersAPI.usersIdPasswordPatch(id: id, user: user) { (response, error) in
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
 **id** | **String** |  | 
 **user** | [**User**](User.md) |  | 

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: text/plain

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **usersIdPatch**
```swift
    open class func usersIdPatch(id: String, user: User, completion: @escaping (_ data: String?, _ error: Error?) -> Void)
```



Updates a user's details by ID.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = "id_example" // String | 
let user = User(id: ObjectId(timestamp: 123), email: "email_example", password: "password_example", lastLogin: Date(), activeSessions: [UserSession(token: "token_example", CSRF: "CSRF_example", validTo: Date())], role: "role_example") // User | 

UsersAPI.usersIdPatch(id: id, user: user) { (response, error) in
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
 **id** | **String** |  | 
 **user** | [**User**](User.md) |  | 

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: text/plain

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **usersPost**
```swift
    open class func usersPost(loginRequest: LoginRequest, completion: @escaping (_ data: String?, _ error: Error?) -> Void)
```



Registers a new user. If the email is already in use, it returns a conflict response.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let loginRequest = LoginRequest(email: "email_example", password: "password_example") // LoginRequest | 

UsersAPI.usersPost(loginRequest: loginRequest) { (response, error) in
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
 **loginRequest** | [**LoginRequest**](LoginRequest.md) |  | 

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

