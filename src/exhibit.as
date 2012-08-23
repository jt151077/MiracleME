import avmplus.getQualifiedClassName;

import com.daveoncode.logging.LogFileTarget;
import com.phidgets.PhidgetInterfaceKit;
import com.phidgets.events.PhidgetDataEvent;
import com.phidgets.events.PhidgetEvent;

import flash.display.StageDisplayState;
import flash.filesystem.File;
import flash.ui.Mouse;
import flash.utils.Dictionary;
import flash.utils.clearInterval;
import flash.utils.setInterval;

import mx.events.FlexEvent;
import mx.logging.ILogger;
import mx.logging.Log;
import mx.logging.LogEventLevel;
import mx.managers.CursorManager;

import org.osmf.events.TimeEvent;

import spark.components.RichEditableText;

private var phid:PhidgetInterfaceKit;
private var lastReadData:Number;
private var resetInterval:Number;
private const RESET_INTERVAL_VALUE:Number = 15000;
private const STEP_TIME:Number = 2000;
private const LOW_LIMIT:Number = 486;
private const HIGH_LIMIT:Number = 514;
private const INPUT_INDEX:Number = 6;
private const PIXEL_INCREMENT:Number = 13;
private const TEMPERATURE_STEP:Number = 15;

[Bindable] private var temperatureLevel:Number = 500;
[Bindable] private var tempTable:Dictionary = new Dictionary();
[Bindable] private var videoSource:String;

[Bindable] private var maxReadVal:Number = 500;
[Bindable] private var minReadVal:Number = 500;

private var countingUp:Boolean = false;
private var countingDown:Boolean = false;

private var warmingInterval:Number;
private var coolingInterval:Number;

private var logger:ILogger;

private const WARMING_TEXT:String = "                                              Varme flyttes fra utsiden (jord, luft eller vann) av huset til innsiden av huset.                                              Du varierer trykket i ulike deler av varmepumpa.                                              I en varmepumpe veksler det derfor mellom væske og gass.                                              Fordampning krever energi og kondensering avgir energi.";
private const COOLING_TEXT:String = "                                              Varme flyttes fra innsiden av huset til utsiden av huset.                                              Du varierer trykket i ulike deler av varmepumpa.                                              I en varmepumpe veksler det derfor mellom væske og gass.                                              Fordampning krever energi og kondensering avgir energi.                                              Et kjøleskap er en varmepumpe.";

protected function initApp(event:FlexEvent):void {
	this.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
	
	// get LogFileTarget's instance (LogFileTarget is a singleton)
	var target:LogFileTarget = LogFileTarget.getInstance();
	// The log file will be placed under applicationStorageDirectory folder
	target.file = File.desktopDirectory.resolvePath("miracleME.log");
	// optional (default to "MM/DD/YY")
	target.dateFormat = "DD/MM/YYYY"; 
	// optional  (default to 1024)
	target.sizeLimit = 1000000000000;
	// Trace all (default Flex's framework features)
	target.filters = ["*"];
	target.level = LogEventLevel.INFO;
	// Begin logging  (default Flex's framework features)
	Log.addTarget(target);
	
	logger = Log.getLogger( getQualifiedClassName(MiracleME).replace("::", ".") );
	logger.info("APPLICATION_START");
	
	tempTable[305] = 5;
	tempTable[320] = 6;
	tempTable[335] = 7;
	tempTable[350] = 8;
	tempTable[365] = 9;
	tempTable[380] = 10;
	tempTable[395] = 11;
	tempTable[410] = 12;
	tempTable[425] = 13;
	tempTable[440] = 14;
	tempTable[455] = 15;
	tempTable[470] = 16;
	tempTable[485] = 17;
	tempTable[500] = 18;
	tempTable[515] = 19;
	tempTable[530] = 20;
	tempTable[545] = 21;
	tempTable[560] = 22;
	tempTable[575] = 23;
	tempTable[590] = 24;
	tempTable[605] = 25;
	tempTable[620] = 26;
	tempTable[635] = 27;
	tempTable[650] = 28;
	tempTable[665] = 29;
	tempTable[680] = 30;
	tempTable[695] = 31;
	
	phid = new PhidgetInterfaceKit();
	phid.addEventListener(PhidgetEvent.CONNECT,	onConnect);
	phid.addEventListener(PhidgetEvent.DETACH,	onDetach);
	phid.addEventListener(PhidgetEvent.DISCONNECT, onDisconnect);
	phid.addEventListener(PhidgetDataEvent.SENSOR_CHANGE, onSensorChange);
	phid.open("localhost", 5001);
}

private function onDetach(evt:PhidgetEvent):void{
	trace("Detached");
}

private function onDisconnect(evt:PhidgetEvent):void{
	trace("Disconnected");
}

private function onConnect(evt:PhidgetEvent):void{
	trace("Connected");
	this.stage.nativeWindow.activate();
	this.stage.nativeWindow.orderToBack();
	this.stage.nativeWindow.orderToFront();
	Mouse.hide();
}

private function onSensorChange(evt:PhidgetDataEvent):void {
	lastReadData = new Number(evt.Data);
	
	if(lastReadData > maxReadVal) {
		maxReadVal = lastReadData;
	}
	
	if(lastReadData < minReadVal && lastReadData != 0) {
		minReadVal = lastReadData;
	}
	
	switch(this.currentState) {
		case "welcome":
			if(evt.Index == INPUT_INDEX && (lastReadData > HIGH_LIMIT || lastReadData < LOW_LIMIT)) {
				this.currentState = "simulation";
				updateIndicator(500);
				swfHP.Temp.tOut.tempOutText.text = tempTable[500];
				swfHP.Temp.tOut.y = 75 - (tempTable[500]-tempTable[305])*PIXEL_INCREMENT;
			}
			break;
		case "simulation":
			if(evt.Index == INPUT_INDEX) {
				if(lastReadData > HIGH_LIMIT) {
					swfHP.mv_default.visible = false;
					swfHP.mv_red.visible = true;
					swfHP.mv_blue.visible = false;
					videoSource = "assets/vids/hpf.mp4";
				}
				else if(lastReadData < LOW_LIMIT) {
					swfHP.mv_default.visible = false;
					swfHP.mv_red.visible = false;
					swfHP.mv_blue.visible = true;
					videoSource = "assets/vids/hp.mp4";
				}
				
				processReadData(lastReadData);
				readVal.text = new String(evt.Data);
				tempVal.text = tempTable[temperatureLevel];	
			}
			break;
	}
}

protected function resetApp():void {
	clearInterval(resetInterval);
	this.currentState = "welcome";
	
}

protected function processReadData(dat:Number):void {
	clearInterval(resetInterval);
	
	if(dat < LOW_LIMIT && banner.text != COOLING_TEXT) {
		txtAnim.stop();
		banner.text = COOLING_TEXT;
		initTxt();
	}
	else if(dat > HIGH_LIMIT && banner.text != WARMING_TEXT) {
		txtAnim.stop();
		banner.text = WARMING_TEXT;
		initTxt();
	}
	
	if(temperatureLevel == 500 && tempVal.text == tempTable[500] && (dat > LOW_LIMIT && dat < HIGH_LIMIT)) {
		trace("standby mode");
		clearInterval(warmingInterval);
		clearInterval(coolingInterval);
		countingUp = false;
		countingDown = false;
		videoSource = "";
		resetInterval = setInterval(resetApp, RESET_INTERVAL_VALUE);
	}
	else {
		txtAnim.resume();
		
		if(dat > temperatureLevel && !countingUp) {
			trace("up temperature detected");
			clearInterval(coolingInterval);
			countingUp = true;
			countingDown = false;
			warmingInterval = setInterval(increaseTemp, STEP_TIME);
		}
		if(dat < temperatureLevel && !countingDown) {
			trace("down temperature detected");
			clearInterval(warmingInterval);
			countingUp = false;
			countingDown = true;
			coolingInterval = setInterval(decreaseTemp, STEP_TIME);
		}
	}
	
	if(dat > LOW_LIMIT && dat < HIGH_LIMIT) {
		txtAnim.pause();
		swfHP.mv_default.visible = true;
		swfHP.mv_red.visible = false;
		swfHP.mv_blue.visible = false;
	}
}

protected function increaseTemp():void {
	clearInterval(warmingInterval);
	temperatureLevel = temperatureLevel + TEMPERATURE_STEP;
	trace("temperature increase: "+temperatureLevel);
	countingUp = false;
	tempVal.text = tempTable[temperatureLevel];
	updateIndicator(temperatureLevel);
	processReadData(lastReadData);
}

protected function updateIndicator(temp:Number):void {
	swfHP.Temp.tHus.tempHusText.text = tempTable[temp];
	swfHP.Temp.tHus.y = 75 - (tempTable[temp]-tempTable[305])*PIXEL_INCREMENT;
}

protected function decreaseTemp():void {
	clearInterval(coolingInterval);
	temperatureLevel = temperatureLevel - TEMPERATURE_STEP;
	trace("temperature decrease: "+temperatureLevel);
	countingDown = false;
	tempVal.text = tempTable[temperatureLevel];
	updateIndicator(temperatureLevel);
	processReadData(lastReadData);
}

protected function videoPlayer_durationChangeHandler(event:TimeEvent):void {
	fadeIn.play();
}

protected function placeCorrectPicture():void {
	if(videoSource == "assets/vids/hpf.mp4") {
		bckImage.source = "assets/pics/cold.png";
	}
	else {
		bckImage.source = "assets/pics/hot.png";
	}				
}

protected function initTxt():void {
	spath.valueFrom = 0;
	spath.valueTo = (banner.textDisplay as RichEditableText).contentWidth - (banner.textDisplay as RichEditableText).width;
	txtAnim.play([banner.textDisplay]);
}