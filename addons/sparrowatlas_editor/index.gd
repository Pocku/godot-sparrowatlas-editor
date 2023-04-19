@tool
extends EditorPlugin

var dock=null;
var sheet=null;
var sprite=null;
var animation=[];
var objects:={};
var editorSelection=get_editor_interface().get_selection();

func _enter_tree() -> void:
	dock=preload("res://addons/sparrowatlas_editor/source/dock.tscn").instantiate();
	dock.name="SparrowAtlas"
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL,dock);
	
	editorSelection.selection_changed.connect(OnEditorSelectionChanged);
	objects["spritePath"]=dock.get_node("VBoxContainer/Sprite/SpritePath");
	objects["apply"]=dock.get_node("VBoxContainer/Apply");
	objects["apply1"]=dock.get_node("VBoxContainer/Apply1");
	objects["save"]=dock.get_node("VBoxContainer/Save");
	objects["sheetPath"]=dock.get_node("VBoxContainer/Sheet/SheetPath");
	objects["offsetX"]=dock.get_node("VBoxContainer/Offset/OffsetX");
	objects["offsetY"]=dock.get_node("VBoxContainer/Offset/OffsetY");
	objects["animIndex"]=dock.get_node("VBoxContainer/Index/Index");
	objects["prefix"]=dock.get_node("VBoxContainer/Prefix/Prefix");
	objects["name"]=dock.get_node("VBoxContainer/Name/Name");
	objects["applyButton"]=dock.get_node("VBoxContainer/Apply");
	objects["target"]=null;
	objects["customOffsetX"]=dock.get_node("VBoxContainer/Offset/OffsetX");
	objects["customOffsetY"]=dock.get_node("VBoxContainer/Offset/OffsetY");
	objects["titleFrames"]=dock.get_node("VBoxContainer/Title9");
	objects["filePath"]=dock.get_node("FilePath");
	
	for key in objects.keys():
		var obj=objects[key];
		if obj!=null:
			if obj.get_class()=="Button":
				if not obj.pressed.is_connected(OnButtonPressed):
					obj.pressed.connect(OnButtonPressed.bind(obj.name));
	
	objects["prefix"].text_changed.connect(PrefixChanged);
	objects["animIndex"].value_changed.connect(OnIndexChanged);
	ToggleEditor(false);
	pass

func _exit_tree() -> void:
	if dock!=null:
		remove_control_from_docks(dock);
	pass

func Notification(what,data):
	match what:
		"UpdateSprite":
			if sprite!=null and sheet!=null:
				var frame=sheet[objects["animIndex"].value];
				if animation.size()>0:
					frame=animation[objects["animIndex"].value];
					
				var spriteCrop=Rect2(int(frame.x),int(frame.y),int(frame.width),int(frame.height));
				var obj=objects["target"];
				if obj!=null:
					obj.texture=sprite;
					obj.region_enabled=true;
					obj.region_rect=spriteCrop;
					obj.offset=-Vector2(int(frame.frameX),int(frame.frameY))+Vector2(objects["customOffsetX"].value,objects["customOffsetY"].value);
			pass;
			
		"NewAnimation":
			objects["animIndex"].value=0;
			objects["animIndex"].max_value=animation.size()-1;
			Notification("UpdateSprite",{});
			pass;
		
		"NoAnimation":
			objects["animIndex"].value=0;
			objects["animIndex"].max_value=sheet.size()-1;
			Notification("UpdateSprite",{});
			pass;
	pass;

func OnEditorSelectionChanged():
	var nodes=editorSelection.get_selected_nodes();
	if not nodes.is_empty():
		var node=nodes[0];
		if node.get_class()=="Sprite2D":
			ToggleEditor(true);
			objects["target"]=node;
			print("target: ",objects["target"])
		else:
			ToggleEditor(false);

func ToggleEditor(state):
	if dock!=null:
		var editableTypes:=["LineEdit","SpinBox","Button","HSlider"];
		if state:
			dock.modulate.a=1.0;
			for key in objects.keys():
				var obj=objects[key];
				if obj!=null:
					if obj.get_class() in editableTypes:
						if obj.get_class()!="Button":
							obj.editable=true;
						else:
							obj.disabled=false;
		else:
			dock.modulate.a=0.5;
			for key in objects.keys():
				var obj=objects[key];
				if obj!=null:
					if obj.get_class() in editableTypes:
						if obj.get_class()!="Button":
							obj.editable=false;
						else:
							obj.disabled=true;

func OnButtonPressed(id):
	match id:
		"Apply":
			if dock!=null:
				var spritePath=objects["spritePath"].text;
				var sheetPath=objects["sheetPath"].text;
				var newSprite = FileAccess;
				var newSheet = FileAccess;
				
				spritePath=str(spritePath).replace('\\',"/");
				sheetPath=str(sheetPath).replace('\\',"/");
				
				if newSprite.file_exists(spritePath):
					newSprite=load(spritePath);
				else:
					newSprite=null;

				if newSheet.file_exists(sheetPath):
					newSheet=ConvertXML(sheetPath);
				else:
					newSheet=null;
					
				sprite=newSprite;
				sheet=newSheet;
				Notification("UpdateSprite",{})
			pass;
				
		"Apply1":
			Notification("UpdateSprite",{});
			pass;
		
		"Save":
			var filePathResponse:=false;
			objects["filePath"].popup();
			
			await objects["filePath"].dir_selected;

			#if not objects["filePath"].get_ok():
			#	print("Couldn't export the new animation properly.");
			#	return;
			#print("Exported the new animation successfully.")
			
			if animation!=null and sheet!=null and sprite!=null:
				var newAnim=Animation.new();
				var newTrackRect=newAnim.add_track(Animation.TYPE_VALUE);
				var newTrackOffset=newAnim.add_track(Animation.TYPE_VALUE);
				
				newAnim.track_set_path(newTrackRect,str(":region_rect"));
				newAnim.track_set_path(newTrackOffset,str(":offset"));
				
				for index in animation.size()-1:
					var frame=animation[index];
					var targetCrop=Rect2(int(frame.x),int(frame.y),int(frame.width),int(frame.height));
					var targetOffset=Vector2(objects["offsetX"].value,objects["offsetY"].value);
					
					newAnim.track_insert_key(newTrackRect,index*0.5,targetCrop,0);
					newAnim.track_insert_key(newTrackOffset,index*0.5,targetOffset,0);
		
				ResourceSaver.save(newAnim, str(objects["filePath"].current_path)+objects["name"].text+".tres")
			pass;
			
		
	pass;

func PrefixChanged(newPrefix):
	animation=[];
	if newPrefix!="":
		var newFrames:=[];
		for frame in sheet:
			if str(frame.name).begins_with(newPrefix):
				newFrames.append(frame);
		animation=newFrames;
		Notification("NewAnimation",{});
	else:
		Notification("NoAnimation",{});
	pass;

func OnIndexChanged(val):
	Notification("UpdateSprite",{});
	if animation.size()>0:
		objects["titleFrames"].text=str(val,"/",animation.size()-1)
	else:
		if sheet!=null:
			objects["titleFrames"].text=str(val,"/",sheet.size()-1)
	
func ConvertXML(path):
	var entries:=["name","width","height","frameX","frameY","x","y"];
	var file=XMLParser.new();
	var result=[];
	file.open(path);
	while file.read()==OK:
		if file.get_named_attribute_value_safe("name")!="":
			var frame={};
			for entry in entries:
				frame[entry]=file.get_named_attribute_value_safe(entry)
			result.append(frame);
	return result;
	pass;
