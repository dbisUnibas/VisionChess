# GamesAPI

All URIs are relative to *https://visionchess.xreco-retrieval.ch*

Method | HTTP request | Description
------------- | ------------- | -------------
[**gamesGet**](GamesAPI.md#gamesget) | **GET** /games | 
[**gamesIdBestMoveSuggestionLevelGet**](GamesAPI.md#gamesidbestmovesuggestionlevelget) | **GET** /games/{id}/bestMove/{suggestionLevel} | 
[**gamesIdDelete**](GamesAPI.md#gamesiddelete) | **DELETE** /games/{id} | 
[**gamesIdGet**](GamesAPI.md#gamesidget) | **GET** /games/{id} | 
[**gamesIdMovePost**](GamesAPI.md#gamesidmovepost) | **POST** /games/{id}/move | 
[**gamesIdMoveValidMoveGet**](GamesAPI.md#gamesidmovevalidmoveget) | **GET** /games/{id}/moveValid/{move} | 
[**gamesIdPatch**](GamesAPI.md#gamesidpatch) | **PATCH** /games/{id} | 
[**gamesPost**](GamesAPI.md#gamespost) | **POST** /games | 


# **gamesGet**
```swift
    open class func gamesGet(completion: @escaping (_ data: [GameResponse]?, _ error: Error?) -> Void)
```



Retrieves all games from the repository.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient


GamesAPI.gamesGet() { (response, error) in
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

[**[GameResponse]**](GameResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gamesIdBestMoveSuggestionLevelGet**
```swift
    open class func gamesIdBestMoveSuggestionLevelGet(id: String, suggestionLevel: String, completion: @escaping (_ data: String?, _ error: Error?) -> Void)
```



Retrieves the best move for a given game state using client engine. <br> Client 

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = "id_example" // String | 
let suggestionLevel = "suggestionLevel_example" // String | 

GamesAPI.gamesIdBestMoveSuggestionLevelGet(id: id, suggestionLevel: suggestionLevel) { (response, error) in
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
 **suggestionLevel** | **String** |  | 

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain, */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gamesIdDelete**
```swift
    open class func gamesIdDelete(id: String, completion: @escaping (_ data: String?, _ error: Error?) -> Void)
```



Deletes a game by ID.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = "id_example" // String | 

GamesAPI.gamesIdDelete(id: id) { (response, error) in
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

# **gamesIdGet**
```swift
    open class func gamesIdGet(id: String, completion: @escaping (_ data: GameResponse?, _ error: Error?) -> Void)
```



Retrieves a specific game by ID.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = "id_example" // String | 

GamesAPI.gamesIdGet(id: id) { (response, error) in
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

[**GameResponse**](GameResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain, */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gamesIdMovePost**
```swift
    open class func gamesIdMovePost(id: String, moveRequest: MoveRequest, completion: @escaping (_ data: MoveResponse?, _ error: Error?) -> Void)
```



Processes a player's move and updates the game state accordingly.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = "id_example" // String | 
let moveRequest = MoveRequest(move: "move_example") // MoveRequest | 

GamesAPI.gamesIdMovePost(id: id, moveRequest: moveRequest) { (response, error) in
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
 **moveRequest** | [**MoveRequest**](MoveRequest.md) |  | 

### Return type

[**MoveResponse**](MoveResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: text/plain, */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gamesIdMoveValidMoveGet**
```swift
    open class func gamesIdMoveValidMoveGet(id: String, move: String, completion: @escaping (_ data: Bool?, _ error: Error?) -> Void)
```





### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = "id_example" // String | 
let move = "move_example" // String | 

GamesAPI.gamesIdMoveValidMoveGet(id: id, move: move) { (response, error) in
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
 **move** | **String** |  | 

### Return type

**Bool**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain, */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gamesIdPatch**
```swift
    open class func gamesIdPatch(id: String, gameUpdateRequest: GameUpdateRequest, completion: @escaping (_ data: String?, _ error: Error?) -> Void)
```



Updates a game by ID.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = "id_example" // String | 
let gameUpdateRequest = GameUpdateRequest(gameState: "gameState_example", moves: ["moves_example"], white: "white_example", black: "black_example", checkers: ["checkers_example"], opponent: "opponent_example", opponentStrength: 123, winner: "winner_example") // GameUpdateRequest | 

GamesAPI.gamesIdPatch(id: id, gameUpdateRequest: gameUpdateRequest) { (response, error) in
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
 **gameUpdateRequest** | [**GameUpdateRequest**](GameUpdateRequest.md) |  | 

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: text/plain

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **gamesPost**
```swift
    open class func gamesPost(gameRequest: GameRequest, completion: @escaping (_ data: String?, _ error: Error?) -> Void)
```



Creates a new game and inserts it into the repository.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let gameRequest = GameRequest(white: "white_example", black: "black_example", opponent: "opponent_example", opponentStrength: 123) // GameRequest | 

GamesAPI.gamesPost(gameRequest: gameRequest) { (response, error) in
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
 **gameRequest** | [**GameRequest**](GameRequest.md) |  | 

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

