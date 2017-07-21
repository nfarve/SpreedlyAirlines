# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org
#/
root = exports ? this
root.token = ""
root.paymentAmount = 10
root.init = false 
ready = ->
	root.token_present = !$('#name').is(':empty')
#	console.log(root.token_present)
	checkShowLogout()

checkShowLogout = (name) ->
	if root.token_present
		$('#logout').show()
		$('#name').text(name)

root.logout = -> 
	$.ajax '/static/logout',
		type: 'GET', 
		success: (data, textStatus, jqXHR) ->
			root.token_present = false
			$('#logout').hide()
			$('#name').text(""); 
		error: (jqHR, textStatus, errorThrown) -> 
			console.log(errorThrown)

root.payment = (amount, type) -> 
	this.paymentAmount = amount
	this.paymentType = type
#	console.log(root.token_present)
	spreedlyInitFunction()
	if root.token_present isnt true  
#		console.log('inside init')
		SpreedlyExpress.init("DWurcqbTfxLYdK2OUOdae5uQUsE", {
			"amount": "$"+amount+".00", 
			"company_name": "Spreedly Airlines"
		});
	else
#		console.log("inside token is present") 
		confirmed = confirm("Purchase this flight with your saved credit card information?")
		if confirmed
			runPayment()

spreedlyInitFunction = -> 
	SpreedlyExpress.onInit =>
		root.init = true 
#		console.log('inside onInit')
		if root.token_present isnt true
#			console.log("opening view")
			SpreedlyExpress.openView();
			if root.paymentType isnt 'priceline'
				 $('.spreedly-sidebar').append "<div style='position:fixed; bottom:5%; left:2%; font-size:12px;'><input type='checkbox' style='position:static; bottom:0' id='saveCard' value='Save Card For Future Purchases'> Save Card For Later Us</div>"
		else
#			console.log("sending payment")
			runPayment()

	SpreedlyExpress.onPaymentMethod (token, paymentMethod, amount) =>
#		console.log('inside Payment method')
		root.token = token;
		runPayment()
		SpreedlyExpress.unload()

runPayment = ->
	paymentData = {token: root.token, amount: root.paymentAmount, payment_type: root.paymentType, saveData: $('#saveCard').is(':checked')}
#	console.log("inside runPayment")
	$.ajax '/static/process_payment', 
		type: 'GET',
		dataType: 'json', 
		data:paymentData,
		success: (data, textStatus, jqXHR) ->
			console.log(data)
			if data.transaction_succeeded
				$('#alert_message').remove() 
				$('#main').prepend "<div id='alert_message' class='alert alert-success' role='alert' style='text-align:center'>Payment Successful</div>"
				root.token_present = data.session_cached
				checkShowLogout(data.session_user_name)
			else
				$('#alert_message').remove() 
				$('#main').prepend "<div id='alert_message' class='alert alert-danger' role='alert' style='text-align:center'>" + data.message + " </div>"
				root.token_present = false
		error: (jqXHR, textStatus, errorThrown) -> 
			$('#alert_message').remove() 
			$('#main').prepend "<div id='alert_message class='alert alert-danger' style='text-align:center' role='alert'> Payment Failed </div>"
	
$(document).ready(ready)
$(document).on('page:load', ready)		
