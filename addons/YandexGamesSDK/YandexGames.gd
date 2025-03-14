extends Node
# autoload_singleton

signal on_initGame()
signal on_showFullscreenAdv(success) # success:bool
signal on_showRewardedVideo(success, ad_name) # success:bool, ad_name:String
signal on_getData(data) # data:Dictionary
signal on_getPlayer(player) # player:JavaScriptObject
signal on_purchase_then(product_id) # product_id:String ("int")
signal on_purchase_catch(product_id)  
signal on_getPurchases_then(purchases) # purchases:Array [productID:String]
signal on_getPurchases_catch()
signal on_getLeaderboards()
signal on_isAvailableMethod(aviable, method_name) # aviable:bool, method_name:String
signal on_canReview(canReview) # canReview:bool
signal on_requestReview(requestReview) # requestReview:bool
signal on_canShowPrompt(canShowPrompt) # canShowPrompt:bool
signal on_showPrompt(accepted) # accepted:bool
# https://yandex.ru/dev/games/doc/en/sdk/sdk-leaderboard#description
# description:{appID:String, default:bool, invert_sort_order:bool, decimal_offset:int, type:String, name:String, title:{en:String, ru:String ..}}
signal on_getLeaderboardDescription(description) # description:Dictionary
# https://yandex.ru/dev/games/doc/en/sdk/sdk-leaderboard#response-format1
# response:{score:int, extraData:String, rank:int, getAvatarSrc:JavaScriptObject, getAvatarSrcSet:JavaScriptObject, lang:String, publicName:String, uniqueID:String, scopePermissions_avatar:String, scopePermissions_public_name:String, formattedScore:String}
signal on_getLeaderboardPlayerEntry_then(response) # response:Dictionary
signal on_getLeaderboardPlayerEntry_catch(err_code) # err_code
# https://yandex.ru/dev/games/doc/en/sdk/sdk-leaderboard#response-format2
# response:{leaderboard:Dictionary, userRank:int, entries:[Dictionary]}
# leaderboard:{ getLeaderboardDescription response }, entries:[{ getLeaderboardPlayerEntry response }]
signal on_getLeaderboardEntries(response) # response:Dictionary

const _print:String = "Addon:YandexGamesSDK, YandexGames.gd"
var _print_debug:bool = true

# Game start - initGame()
var js_callback_initGame = JavaScript.create_callback(self, "js_callback_initGame")
# Managing ads - showFullscreenAdv()
var js_callback_showFullscreenAdv_onClose = JavaScript.create_callback(self, "js_callback_showFullscreenAdv_onClose")
var js_callback_showFullscreenAdv_onError = JavaScript.create_callback(self, "js_callback_showFullscreenAdv_onError")
# Managing ads - showRewardedVideo()
var js_callback_showRewardedVideo_onClose = JavaScript.create_callback(self, "js_callback_showRewardedVideo_onClose")
var js_callback_showRewardedVideo_onError = JavaScript.create_callback(self, "js_callback_showRewardedVideo_onError")
var js_callback_showRewardedVideo_onRewarded = JavaScript.create_callback(self, "js_callback_showRewardedVideo_onRewarded")
# Player details - getPlayer()
var js_callback_getPlayer = JavaScript.create_callback(self, "js_callback_getPlayer")
# Player details - getData()
var js_callback_getData = JavaScript.create_callback(self, "js_callback_getData")
# In-game purchases - getPayments()
var js_callback_getPayments_then = JavaScript.create_callback(self, "js_callback_getPayments_then")
var js_callback_getPayments_catch = JavaScript.create_callback(self, "js_callback_getPayments_catch")
# In-game purchases - purchase()
var js_callback_purchases_then = JavaScript.create_callback(self, "js_callback_purchases_then")
var js_callback_purchases_catch = JavaScript.create_callback(self, "js_callback_purchases_catch")
# In-game purchases - getPurchases()
var js_callback_getPurchases_then = JavaScript.create_callback(self, "js_callback_getPurchases_then")
var js_callback_getPurchases_catch = JavaScript.create_callback(self, "js_callback_getPurchases_catch")
# Leaderboards - getLeaderboards()
var js_callback_getLeaderboards = JavaScript.create_callback(self, "js_callback_getLeaderboards")
# Leaderboards - getLeaderboardDescription()
var js_callback_getLeaderboardDescription = JavaScript.create_callback(self, "js_callback_getLeaderboardDescription")
# Leaderboards - getLeaderboardPlayerEntry()
var js_callback_getLeaderboardPlayerEntry_then = JavaScript.create_callback(self, "js_callback_getLeaderboardPlayerEntry_then")
var js_callback_getLeaderboardPlayerEntry_catch = JavaScript.create_callback(self, "js_callback_getLeaderboardPlayerEntry_catch")
# Leaderboards - getLeaderboardEntries()
var js_callback_getLeaderboardEntries_then = JavaScript.create_callback(self, "js_callback_getLeaderboardEntries_then")
var js_callback_getLeaderboardEntries_catch = JavaScript.create_callback(self, "js_callback_getLeaderboardEntries_catch")
# Game rating
var js_callback_canReview = JavaScript.create_callback(self, "js_callback_canReview")
var js_callback_requestReview = JavaScript.create_callback(self, "js_callback_requestReview")
# Desktop shortcut
var js_callback_canShowPrompt = JavaScript.create_callback(self, "js_callback_canShowPrompt")
var js_callback_showPrompt = JavaScript.create_callback(self, "js_callback_showPrompt")

var js_callback_isAvailableMethod = JavaScript.create_callback(self, "js_callback_isAvailableMethod")

var is_initGame:bool = false
var js_ysdk:JavaScriptObject
var js_ysdk_player
var js_ysdk_payments
var js_ysdk_lb
var current_rewarded_ad_name = ""

var _saved_data_json:String = "" # DO NOT USE! PRIVATE VARIABLE
var _get_data:Dictionary # DO NOT USE! PRIVATE VARIABLE
var _current_purchase_is_consume:bool # DO NOT USE! PRIVATE VARIABLE
var _current_purchase_produc_id:String = "" # DO NOT USE! PRIVATE VARIABLE
var _current_isAvailableMethod:String = "" # DO NOT USE! PRIVATE VARIABLE
var _current_isAvailableMethod_result:bool # DO NOT USE! PRIVATE VARIABLE
var _current_canReview:bool # DO NOT USE! PRIVATE VARIABLE
var _current_canShowPrompt:bool # DO NOT USE! PRIVATE VARIABLE
var _current_rewarded_success:bool # DO NOT USE! PRIVATE VARIABLE

func _ready():
	if OS.has_feature("HTML5"):
		print("%s, _ready() OS.has_feature('HTML5') - addon works"%[_print])
		initGame()
		yield(self, "on_initGame")
		getPlayer(false)
		getPayments()
		getLeaderboards()
	else:
		print("%s, _ready() !OS.has_feature('HTML5') - addon doesn't work, platform is not html"%[_print])

# https://yandex.ru/dev/games/doc/en/sdk/sdk-gameready
# Game start - initGame()
# auto-call from _ready()
func initGame():
	if _print_debug: print("%s initGame()"%[_print])
	if !OS.has_feature("HTML5"):
		if _print_debug: print("%s, initGame() !OS.has_feature('HTML5') - addon doesn't work, platform is not html"%[_print])
		return
	var js_window:JavaScriptObject = JavaScript.get_interface("window")
	var js_console:JavaScriptObject = JavaScript.get_interface("console")
#	var js_dictionary:JavaScriptObject = JavaScript.create_object("object")
	js_window.YaGames.init().then(js_callback_initGame)

func js_callback_initGame(args:Array):
	if _print_debug: print("%s js_callback_initGame(args:%s)"%[_print, args])
	js_ysdk = args[0]
	js_ysdk.features.LoadingAPI.ready()
	is_initGame = true
	emit_signal("on_initGame")
	if _print_debug: print("%s js_callback_initGame(args:%s) is_initGame = true"%[_print, args])

# https://yandex.ru/dev/games/doc/en/sdk/sdk-adv
# Managing ads
# Managing ads - showFullscreenAdv()
func showFullscreenAdv():
	if not _check_func_valid("showFullscreenAdv", []): return
	var js_dictionary:JavaScriptObject = JavaScript.create_object("Object")
	var js_dictionary_2:JavaScriptObject = JavaScript.create_object("Object")
	var js_console:JavaScriptObject = JavaScript.get_interface("console")
	js_dictionary_2["onClose"] = js_callback_showFullscreenAdv_onClose
	js_dictionary_2["onError"] = js_callback_showFullscreenAdv_onError
	js_dictionary["callbacks"] = js_dictionary_2
	if _print_debug: js_console.log(js_dictionary)
	js_ysdk.adv.showFullscreenAdv(js_dictionary)

func js_callback_showFullscreenAdv_onClose(args:Array):
	if _print_debug: print("%s js_callback_showFullscreenAdv_onClose(args:%s)"%[_print, args])
	var wasShown:bool = args[0]
	emit_signal("on_showFullscreenAdv", wasShown)
func js_callback_showFullscreenAdv_onError(args:Array):
	if _print_debug: print("%s js_callback_showFullscreenAdv_onError(args:%s)"%[_print, args])
	emit_signal("on_showFullscreenAdv", false)

# Managing ads - showRewardedVideo()
func showRewardedVideo(new_current_rewarded_ad_name:String):
	if not _check_func_valid("showRewardedVideo", [new_current_rewarded_ad_name]): return

	_current_rewarded_success = false
	current_rewarded_ad_name = new_current_rewarded_ad_name
	var js_dictionary:JavaScriptObject = JavaScript.create_object("Object")
	var js_dictionary_2:JavaScriptObject = JavaScript.create_object("Object")
	var js_console:JavaScriptObject = JavaScript.get_interface("console")
	js_dictionary_2["onClose"] = js_callback_showRewardedVideo_onClose
	js_dictionary_2["onError"] = js_callback_showRewardedVideo_onError
	js_dictionary_2["onRewarded"] = js_callback_showRewardedVideo_onRewarded
	js_dictionary["callbacks"] = js_dictionary_2
	if _print_debug: js_console.log(js_dictionary)
	js_ysdk.adv.showRewardedVideo(js_dictionary)

func js_callback_showRewardedVideo_onClose(args:Array):
	if _print_debug: print("%s js_callback_showRewardedVideo_onClose(args:%s)"%[_print, args])
	var ad_name = current_rewarded_ad_name
	current_rewarded_ad_name = ""
	emit_signal("on_closeRewardedVideo", _current_rewarded_success, ad_name)
func js_callback_showRewardedVideo_onError(args:Array):
	if _print_debug: print("%s js_callback_showRewardedVideo_onError(args:%s)"%[_print, args])
	var ad_name = current_rewarded_ad_name
	_current_rewarded_success = false
	emit_signal("on_showRewardedVideo", _current_rewarded_success, ad_name)
func js_callback_showRewardedVideo_onRewarded(args:Array):
	if _print_debug: print("%s js_callback_showRewardedVideo_onRewarded(args:%s)"%[_print, args])
	_current_rewarded_success = true

# https://yandex.ru/dev/games/doc/en/sdk/sdk-player#auth
# Player details
# Player details - getPlayer()
func getPlayer(scopes:bool):
	if not _check_func_valid("getPlayer", [scopes]): return
	var js_dictionary:JavaScriptObject = JavaScript.create_object("Object")
	js_dictionary["scopes"] = scopes
	js_ysdk.getPlayer(js_dictionary).then(js_callback_getPlayer)

func getPlayer_yield(scopes:bool):
	if not _check_func_valid("getPlayer_yield", [scopes]): return
	getPlayer(scopes)
	yield(self, "on_getPlayer")

func js_callback_getPlayer(args:Array):
	if _print_debug: 
		print("%s js_callback_getPlayer(args:%s)"%[_print, args])
		var js_console = JavaScript.get_interface("console")
		js_console.log(args[0])
	js_ysdk_player = args[0]
	emit_signal("on_getPlayer", js_ysdk_player)

# https://yandex.ru/dev/games/doc/en/sdk/sdk-player#ingame-data
# Player details
# Player details setData()
func setData(data:Dictionary):
	if not _check_func_valid("setData", []): return
	if js_ysdk_player == null: 
		if _print_debug: print("%s setData(data) js_ysdk_player == null"%[_print])
		return
	var json_data:String = to_json(data)
	if _saved_data_json == json_data: return
	else: _saved_data_json = json_data
	var js_dictionary:JavaScriptObject = JavaScript.create_object("Object")
	var js_console = JavaScript.get_interface("console")
	js_dictionary["json_data"] = json_data
	js_ysdk_player.setData(js_dictionary).then(js_console.log("YandexGamesSDK setData success"))

# Player details - getData()
func getData():
	if not _check_func_valid("getData", []): return
	if js_ysdk_player == null: 
		if _print_debug: print("%s getData(data) js_ysdk_player == null"%[_print])
		return
	js_ysdk_player.getData().then(js_callback_getData)
	return

func getData_yield() -> Dictionary:
	if not _check_func_valid("getData_yield", []): return
	var result:Dictionary
	getData()
	yield(self, "on_getData")
	result = _get_data
	_get_data = {}
	return result

func js_callback_getData(args:Array):
	if _print_debug: print("js_callback_getData(args:%s)"%[args])
	var js_console = JavaScript.get_interface("console")
	var data:Dictionary = JSON.parse(args[0]["json_data"]).result
	if _print_debug: print("js_callback_getData data: ", data)
	_get_data = data
	emit_signal("on_getData", data)

# https://yandex.ru/dev/games/doc/en/sdk/sdk-purchases#install
# In-game purchases
# In-game purchases - getPayments()
func getPayments():
	if not _check_func_valid("getPayments", []): return
	var js_dictionary:JavaScriptObject = JavaScript.create_object("Object")
	js_dictionary["signed"] = true
	js_ysdk.getPayments(js_dictionary).then(js_callback_getPayments_then).catch(js_callback_getPayments_catch)

func js_callback_getPayments_then(args:Array):
	if _print_debug: 
		print("js_callback_getPayments_then args: ", args)
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	js_ysdk_payments = args[0]

func js_callback_getPayments_catch(args:Array):
	if _print_debug: 
		print("js_callback_getPayments_catch args: ", args)
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])

# https://yandex.ru/dev/games/doc/en/sdk/sdk-purchases#payments-purchase
# In-game purchases - purchase()
func purchase(id:String, consume_purchase:bool):
	if not _check_func_valid("purchase", [id, consume_purchase]): return
	if js_ysdk_payments == null:
		if _print_debug: print("%s purchase(id:%s) js_ysdk_payments == null"%[_print, id])
		return
	var js_dictionary:JavaScriptObject = JavaScript.create_object("Object")
#	var js_console = JavaScript.get_interface("console")
	js_dictionary["id"] = id
	_current_purchase_is_consume = consume_purchase
	_current_purchase_produc_id = id
	js_ysdk_payments.purchase(js_dictionary).then(js_callback_purchases_then).catch(js_callback_purchases_catch)

func js_callback_purchases_then(args:Array):
	if _print_debug: 
		print("js_callback_purchases_then args: ", args)
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	var purchase = args[0]
	var purchase_productID:String = purchase.productID
	if _current_purchase_is_consume:
		js_ysdk_payments.consumePurchase(purchase.purchaseToken)
	emit_signal("on_purchase_then", purchase_productID)

func js_callback_purchases_catch(args:Array):
	if _print_debug: 
		print("js_callback_purchases_catch args: ", args)
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	var copy_current_purchase_produc_id = _current_purchase_produc_id
	_current_purchase_produc_id = ""
	emit_signal("on_purchase_catch", copy_current_purchase_produc_id)

func getPurchases():
	if not _check_func_valid("getPurchases", []): return
	if js_ysdk_payments == null:
		if _print_debug: print("%s getPurchases js_ysdk_payments == null"%[_print])
		return
	js_ysdk_payments.getPurchases().then(js_callback_getPurchases_then).catch(js_callback_getPurchases_catch)

func js_callback_getPurchases_then(args:Array):
	if _print_debug:
		print("%s js_callback_getPurchases_then(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
		js_console.log(args[0].length)
		js_console.log(args[0][0])
	var result:Array = []
	var arr_length = args[0].length
	for id in args[0].length:
		result.append(args[0][id].productID)
	emit_signal("on_getPurchases_then", result)

func js_callback_getPurchases_catch(args:Array):
	if _print_debug:
		print("%s js_callback_getPurchases_then(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	emit_signal("on_getPurchases_catch")

# https://yandex.ru/dev/games/doc/en/sdk/sdk-leaderboard
# Leaderboards
# Leaderboards - getLeaderboards()
func getLeaderboards():
	if not _check_func_valid("getLeaderboards", []): return
	js_ysdk_lb = js_ysdk.getLeaderboards().then(js_callback_getLeaderboards)

func js_callback_getLeaderboards(args:Array):
	if _print_debug: 
		print("%s js_callback_getLeaderboards(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	js_ysdk_lb = args[0]
	emit_signal("on_getLeaderboards")

# Leaderboards - getLeaderboardDescription(), https://yandex.ru/dev/games/doc/en/sdk/sdk-leaderboard#description
func getLeaderboardDescription(leaderboardName:String):
	if not _check_func_valid("getLeaderboardDescription", [leaderboardName]): return
	if js_ysdk_lb == null:
		if _print_debug: print("%s getLeaderboardDescription(leaderboardName:%s) js_ysdk_lb == null"%[_print, leaderboardName])
		return
	js_ysdk_lb.getLeaderboardDescription(leaderboardName).then(js_callback_getLeaderboardDescription)

func js_LeaderboardDescription_to_Dictionary(object:JavaScriptObject) -> Dictionary:
	var description:Dictionary = {'appID':'null', 'default':false, 'invert_sort_order':false, 'decimal_offset':-1, 'type':'null', 'name':'null', 'title':{}}
	description['appID'] = object['appID']
	description['default'] = object['default']
	description['invert_sort_order'] = object['description']['invert_sort_order']
	description['decimal_offset'] = object['description']['score_format']['options']['decimal_offset']
	description['type'] = object['description']['score_format']['type']
	description['name'] = object['name']
	var js_Object = JavaScript.get_interface("Object")
	var js_ArrayKeys = js_Object.keys(object['title'])
	for key_id in js_ArrayKeys.length:
		var key = js_ArrayKeys[key_id]
		description['title'][key] = object['title'][key]
	return description

func js_LeaderboardPlayerEntry_to_Dictionary(object:JavaScriptObject) -> Dictionary:
	var response:Dictionary = {'score':-1, 'extraData':'null', 'rank':-1, 'getAvatarSrc':'null', 'getAvatarSrcSet':'null', 'lang':'null', 'publicName':'null', 'uniqueID':'null', 'scopePermissions_avatar':'null', 'scopePermissions_public_name':'null', 'formattedScore':'null'}
	response['score'] = object['score']
	response['extraData'] = object['player']
	response['rank'] = object['rank']
	response['getAvatarSrc'] = object['player']['getAvatarSrc']
	response['getAvatarSrcSet'] = object['player']['getAvatarSrcSet']
	response['lang'] = object['player']['lang']
	response['publicName'] = object['player']['publicName']
	response['scopePermissions_avatar'] = object['player']['scopePermissions']['avatar']
	response['scopePermissions_public_name'] = object['player']['scopePermissions']['public_name']
	response['uniqueID'] = object['player']['uniqueID']
	response['formattedScore'] = object['formattedScore']
	return response

func js_callback_getLeaderboardDescription(args:Array):
	if _print_debug: 
		print("%s js_callback_getLeaderboardDescription(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	var js_desc:JavaScriptObject = args[0]
	var description:Dictionary = js_LeaderboardDescription_to_Dictionary(js_desc)
	if _print_debug: print("%s, js_callback_getLeaderboardDescription() description:%s"%[_print, description])
	emit_signal("on_getLeaderboardDescription", description)

# Leaderboards - setLeaderboardScore(), https://yandex.ru/dev/games/doc/en/sdk/sdk-leaderboard#set-score
func setLeaderboardScore(leaderboardName:String, score:int):
	if not _check_func_valid("setLeaderboardScore", [leaderboardName, score]): return
	if js_ysdk_lb == null:
		if _print_debug: print("%s setLeaderboardScore(leaderboardName:%s, score:%s) js_ysdk_lb == null"%[_print, leaderboardName, score])
		return
	_current_isAvailableMethod = 'leaderboards.setLeaderboardScore'
	js_ysdk.isAvailableMethod('leaderboards.setLeaderboardScore').then(js_callback_isAvailableMethod)
	yield(self, "on_isAvailableMethod")
	if _current_isAvailableMethod_result == true:
		js_ysdk_lb.setLeaderboardScore(leaderboardName, score)
		if _print_debug: print("%s setLeaderboardScore() js_ysdk_lb.setLeaderboardScore(leaderboardName:%s, score:%s) request"%[_print, leaderboardName, score])
	elif _print_debug: print("%s setLeaderboardScore() js_ysdk_lb.setLeaderboardScore(leaderboardName:%s, score:%s) isAvailableMethod('leaderboards.setLeaderboardScore') == false"%[_print, leaderboardName, score])

func js_callback_isAvailableMethod(args:Array):
	if _print_debug: print("%s js_callback_isAvailableMethod(args:%s)"%[_print, args])
	_current_isAvailableMethod_result = args[0]
	emit_signal("on_isAvailableMethod", _current_isAvailableMethod_result, _current_isAvailableMethod)

# Leaderboards - getLeaderboardPlayerEntry(), https://yandex.ru/dev/games/doc/en/sdk/sdk-leaderboard#get-entry
func getLeaderboardPlayerEntry(leaderboardName:String):
	if not _check_func_valid("getLeaderboardPlayerEntry", [leaderboardName]): return
	if js_ysdk_lb == null:
		if _print_debug: print("%s getLeaderboardDescription(leaderboardName:%s) js_ysdk_lb == null"%[_print, leaderboardName])
		return
	js_ysdk_lb.getLeaderboardPlayerEntry(leaderboardName).then(js_callback_getLeaderboardPlayerEntry_then).catch(js_callback_getLeaderboardPlayerEntry_catch)

func js_callback_getLeaderboardPlayerEntry_then(args:Array):
	if _print_debug:
		print("%s js_callback_getLeaderboardPlayerEntry_then(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	var js_response:JavaScriptObject = args[0]
	var response:Dictionary = js_LeaderboardPlayerEntry_to_Dictionary(js_response)
	if _print_debug: print("%s js_callback_getLeaderboardPlayerEntry_then() response:%s"%[_print, response])
	emit_signal("on_getLeaderboardPlayerEntry_then", response)

func js_callback_getLeaderboardPlayerEntry_catch(args:Array):
	if _print_debug: 
		print("%s js_callback_getLeaderboardPlayerEntry_catch(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	emit_signal("on_getLeaderboardPlayerEntry_catch", args[0].code)

# Leaderboards - getLeaderboardEntries(), https://yandex.ru/dev/games/doc/ru/sdk/sdk-leaderboard#get-entries
func getLeaderboardEntries(leaderboardName:String):
	if not _check_func_valid("getLeaderboardEntries", [leaderboardName]): return
	if js_ysdk_lb == null:
		if _print_debug: print("%s getLeaderboardEntries(leaderboardName:%s) js_ysdk_lb == null"%[_print, leaderboardName])
		return
	var js_dictionary:JavaScriptObject = JavaScript.create_object("object")
	js_dictionary["quantityTop"] = 20
	js_dictionary["quantityAround"] = 10
	js_dictionary["includeUser"] = true
	js_ysdk_lb.getLeaderboardEntries(leaderboardName, js_dictionary).then(js_callback_getLeaderboardEntries_then)

func js_callback_getLeaderboardEntries_then(args:Array):
	if _print_debug: 
		print("%s js_callback_getLeaderboardEntries_then(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	var response:Dictionary = {'leaderboard': {}, 'userRank':-1, 'entries':[]}
	response['leaderboard'] = js_LeaderboardDescription_to_Dictionary(args[0]['leaderboard'])
	response['userRank'] = args[0]['userRank']
	for js_Object_id in args[0]['entries'].length:
		response['entries'].append(js_LeaderboardPlayerEntry_to_Dictionary(args[0]['entries'][js_Object_id]))
	if _print_debug: print("%s js_callback_getLeaderboardEntries_then() response:%s"%[_print, response])
	emit_signal("on_getLeaderboardEntries", response)

func js_callback_getLeaderboardEntries_catch(args:Array):
	if _print_debug: 
		print("%s js_callback_getLeaderboardEntries_catch(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])

# https://yandex.ru/dev/games/doc/en/sdk/sdk-review
# Game rating
# Game rating - canReview()
func canReview():
	if not _check_func_valid("canReview", []): return
	js_ysdk.feedback.canReview().then(js_callback_canReview)

func on_canReview_yield() -> bool:
	if not _check_func_valid("on_canReview_yield", []): return
	var result:bool 
	canReview()
	yield(self, "on_canReview")
	result = _current_canReview
	return result

func js_callback_canReview(args:Array):
	if _print_debug: 
		print("%s js_callback_canReview(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	if args[0]["value"]:
		if _print_debug: 
			print("%s js_callback_canReview(args:%s) canReview == true"%[_print, args])
		_current_canReview = true
		emit_signal("on_canReview", true)
	else:
		if _print_debug: 
			print("%s js_callback_canReview(args:%s) canReview == false"%[_print, args])
			var js_console:JavaScriptObject = JavaScript.get_interface("console")
			js_console.log(args[0]["reason"])
		_current_canReview = false
		emit_signal("on_canReview", false)

# Game rating - requestReview()
func requestReview():
	if not _check_func_valid("requestReview", []): return
	canReview()
	yield(self, "on_canReview")
	if _current_canReview:
		js_ysdk.feedback.requestReview().then(js_callback_requestReview)
	elif _print_debug: print("%s requestReview() _current_canReview = false"%[_print])

func js_callback_requestReview(args:Array):
	if _print_debug: 
		print("%s js_callback_requestReview(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0])
	emit_signal("on_requestReview", args[0])

# return user lang - en/ru/tr/...
func getLang() -> String:
	var result:String
	if not _check_func_valid("getLang", []): return "!is_initGame. Call the function after the initGame event"
	if js_ysdk_player == null:
		result = js_ysdk.environment.i18n.lang
		if _print_debug: print("%s getLang() js_ysdk_player == null, result: %s"%[_print, result])
		return result
	else:
		result = js_ysdk_player._personalInfo.lang
		if _print_debug: print("%s getLang() result: %s"%[_print, result])
	return result

# https://yandex.ru/dev/games/doc/en/sdk/sdk-shortcut
# Desktop shortcut
# Desktop shortcut - canShowPrompt()
func canShowPrompt():
	if not _check_func_valid("canShowPrompt", []): return
	js_ysdk.shortcut.canShowPrompt().then(js_callback_canShowPrompt)

func js_callback_canShowPrompt(args:Array):
	if _print_debug: 
		print("%s js_callback_canShowPrompt(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0].canShow)
	_current_canShowPrompt = args[0].canShow
	emit_signal("on_canShowPrompt", _current_canShowPrompt)

func canShowPrompt_yield() -> bool:
	if not _check_func_valid("canShowPrompt_yield", []): return
	var result:bool
	canShowPrompt()
	yield(self,"on_canShowPrompt")
	result = _current_canShowPrompt
	return result

# Desktop shortcut - showPrompt()
func showPrompt():
	if not _check_func_valid("showPrompt", []): return
	canShowPrompt()
	yield(self, "on_canShowPrompt")
	if _current_canShowPrompt:
		js_ysdk.shortcut.showPrompt().then(js_callback_showPrompt)
	elif _print_debug: print("%s showPrompt() _current_canShowPrompt = false"%[_print])

func js_callback_showPrompt(args:Array):
	if _print_debug: 
		print("%s js_callback_showPrompt(args:%s)"%[_print, args])
		var js_console:JavaScriptObject = JavaScript.get_interface("console")
		js_console.log(args[0].outcome)
	emit_signal("on_showPrompt", args[0].outcome == 'accepted')

# private function. NOT USE
func _check_func_valid(print_function_name:String, args:Array) -> bool:
	var is_valid:bool = true
	if _print_debug: print("%s %s(args:%s)"%[_print, print_function_name, args])
	if !OS.has_feature("HTML5"):
		if _print_debug: print("%s, %s(args:%s) !OS.has_feature('HTML5') - addon doesn't work, platform is not html"%[_print, print_function_name, args])
		is_valid = false
	if !is_initGame:
		if _print_debug: print("%s %s(args:%s) is_initGame == false"%[_print, print_function_name, args])
		is_valid = false
	return is_valid
