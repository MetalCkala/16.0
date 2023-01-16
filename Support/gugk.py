# coding: windows-1251
import clr
import dlr
clr.AddReference("Topomatic.Dwg")
clr.AddReference("Topomatic.Planchet")
clr.AddReference("Topomatic.Cad.Foundation")
clr.AddReference("System.Xml")
import Topomatic
import System

clr.AddReference("System.Windows.Forms")
clr.AddReference("Topomatic.Cad.View")

ps1 = "g_"

@dlr.params(Topomatic.Dwg.DwgLayer, Topomatic.Dwg.DwgLayer)
def replace_layer(source, dest):
	"""Заменяет слой source на слой dest и удаляет из чертежа слой source"""
	if (source.IsSystem):
		return
	drawing = source.Drawing
	if (drawing.ActiveLayer == source):
		drawing.ActiveLayer = drawing.Layers.Layer0
	for i in xrange(0, drawing.Blocks.Count):
		block = drawing.Blocks[i]
		for j in xrange(0, block.Count):
			e = block[j]
			if (e.Layer == source):
				e.Layer = dest
			if (isinstance(e, Topomatic.Dwg.Entities.DwgInsert)):
				for attr in e.Attribs:
					if (attr.Layer == source):
						attr.Layer = dest
	
	if (not drawing.UseReference(source)):
		drawing.Layers.RemoveAt(source.Index)
		
@dlr.params(Topomatic.Dwg.DwgBlock, str)
def rename_block(block, name):
	"""Переименовывает блок и если блок с таким именем уже существует, то удаляет исходный блок"""
	if (block.IsSystem):
		return
	drawing = block.Drawing
	exists = drawing.Blocks[name]
	if ((exists != None) and (exists != block)):
		if (exists.IsSystem):
			raise AssertionError(str.Format("Existing block \"{0}\" is system.", exists.Name))
		for i in xrange(0, drawing.Blocks.Count):
			b = drawing.Blocks[i]
			if (b != exists):
				for j in xrange(0, b.Count):
					e = b[j]
					if ((isinstance(e, Topomatic.Dwg.Entities.DwgInsert)) and (e.Block == exists)):
						e.Block = block
		if (not drawing.UseReference(exists)):
			drawing.Blocks.Remove(exists)
	if (str.IsNullOrEmpty(block.Description)):
		block.Description = block.Name
	block.Name = name;
		
@dlr.params(Topomatic.Dwg.DwgStyle, str)
def rename_style(style, name):
	"""Переименовывает стиль и если стиль с таким именем уже существует, то удаляет исходный стиль"""
	if (style.IsSystem):
		return
	drawing = style.Drawing
	exists = drawing.Styles[name]
	if ((exists != None) and (exists != style)):
		# Текущий текстовый стиль
		if (drawing.ActiveStyle == style):
			drawing.ActiveStyle = drawing.Styles.Standard
		# Размерные стили
		for i in xrange(0, drawing.DimensionStyles.Count):
			if (drawing.DimensionStyles[i].TextStyle == style):
				drawing.DimensionStyles[i].TextStyle = exists
		# Примитивы
		for i in xrange(0, drawing.Blocks.Count):
			b = drawing.Blocks[i]
			for j in xrange(0, b.Count):
				e = b[j]
				if ((isinstance(e, Topomatic.Dwg.Entities.DwgText)) and (e.Style == style)):
					e.Style = exists
				elif ((isinstance(e, Topomatic.Dwg.Entities.DwgMText)) and (e.Style == style)):
					e.Style = exists
				elif ((isinstance(e, Topomatic.Dwg.Entities.DwgDimension)) and (e.TextStyle == style)):
					e.TextStyle = exists
				elif ((isinstance(e, Topomatic.Dwg.Entities.DwgShape)) and (e.ShapeStyle == style)):
					e.ShapeStyle = exists
		# Удаление
		if (not drawing.UseReference(style)):
			drawing.Styles.Remove(style)
	else:
		style.Name = name;
		
@dlr.params(Topomatic.Dwg.DwgLinetype, str)
def rename_linetype(linetype, name):
	"""Переименовывает тип линии и если тип линии с таким именем уже существует, то удаляет исходный"""
	if (linetype.IsSystem):
		return
	drawing = linetype.Drawing
	exists = drawing.Linetypes[name]
	if ((exists != None) and (exists != linetype)):
		# Текущий тип линии
		if (drawing.ActiveLinetype == linetype):
			drawing.ActiveLinetype = drawing.Linetypes.ByLayer
		# Слои
		for i in xrange(0, drawing.Layers.Count):
			if (drawing.Layers[i].Linetype == linetype):
				drawing.Layers[i].Linetype = exists
		# Размерные стили
		for i in xrange(0, drawing.DimensionStyles.Count):
			if (drawing.DimensionStyles[i].DimentionLinetype == linetype):
				drawing.DimensionStyles[i].DimentionLinetype = exists
			if (drawing.DimensionStyles[i].ExtensionLinetype1 == linetype):
				drawing.DimensionStyles[i].ExtensionLinetype1 = exists
			if (drawing.DimensionStyles[i].ExtensionLinetype2 == linetype):
				drawing.DimensionStyles[i].ExtensionLinetype2 = exists
		# Состояния слоёв
		for i in xrange(0, drawing.LayerStates.Count):
			state = drawing.LayerStates[i]
			for layer in state:
				if (layer.Linetype == linetype):
					layer.Linetype = exists
		# Мульти линии
		for i in xrange(0, drawing.MLineStyles.Count):
			mline_style = drawing.MLineStyles[i]
			for j in xrange(0, mline_style.Count):
				if (mline_style[j].Linetype == linetype):
					mline_style[j].Linetype = exists
		# Примитивы
		for i in xrange(0, drawing.Blocks.Count):
			b = drawing.Blocks[i]
			for j in xrange(0, b.Count):
				e = b[j]
				if (e.Linetype == linetype):
					e.Linetype = exists
				if (isinstance(e, Topomatic.Dwg.Entities.DwgDimension)):
					if (e.DimentionLinetype == linetype):
						e.DimentionLinetype = exists
					if (e.ExtensionLinetype1 == linetype):
						e.ExtensionLinetype1 = exists
					if (e.ExtensionLinetype2 == linetype):
						e.ExtensionLinetype2 = exists
				
		# Удаление
		if (not drawing.UseReference(linetype)):
			drawing.Linetypes.Remove(linetype)
	else:
		linetype.Name = name;

@dlr.params(Topomatic.Dwg.Drawing, System.Xml.XmlElement)
def applay_layers_conversion(drawing, node):
	"""Переименование слоев в соответствии с параметрами из файла gugk.xml"""
	dictionary = System.Collections.Generic.Dictionary[str, bool]()
	defaultLayerNode = node.Attributes.GetNamedItem("Default")
	defaultLayerName = None
	if (defaultLayerNode != None):
		defaultLayerName = defaultLayerNode.Value
	for child in node.ChildNodes:
		if (child.NodeType == System.Xml.XmlNodeType.Element):
			#region Layer conversions
			if (child.Name == "Layer"):
				pattern = None
				regexNode = child.Attributes.GetNamedItem("Regex")
				if (regexNode != None):
					pattern = regexNode.Value
				name = child.InnerText
				
				layer = drawing.Layers[name]
				if (layer == None):
					layer = drawing.Layers.Add(name)
				
				if (layer.Name != name):
					layer.Name = name
				dictionary[name] = True
				
				if (not str.IsNullOrEmpty(pattern)):
					Topomatic.Cad.View.ConsoleListner.Current.WriteLine(pattern)
					regex = System.Text.RegularExpressions.Regex(pattern)
					for i in xrange(drawing.Layers.Count - 1, -1, -1):
						source = drawing.Layers[i]
						if (source != layer):
							if (regex.IsMatch(source.Name)):
								replace_layer(source, layer)
					
			else:
				raise AssertionError(System.String.Format("Unknown layer conversion element {0}", child.Name))
			#endregion
	if (not str.IsNullOrEmpty(defaultLayerName)):
		defaultLayer = drawing.Layers[defaultLayerName];
		if (defaultLayer == None):
			defaultLayer = drawing.Layers.Add(defaultLayerName)
		for i in xrange(drawing.Layers.Count - 1, -1, -1):
			source = drawing.Layers[i]
			if ((not dictionary.ContainsKey(source.Name)) and (source != defaultLayer)):
				replace_layer(source, defaultLayer)
		if (not drawing.UseReference(defaultLayer)):
			drawing.Layers.RemoveAt(defaultLayer.Index)
				
@dlr.params(Topomatic.Dwg.Drawing, System.Xml.XmlElement)
def applay_blocks_conversion(drawing, node):
	"""Переименование блоков в соответствии с параметрами из файла gugk.xml"""
	for child in node.ChildNodes:
		if (child.NodeType == System.Xml.XmlNodeType.Element):
			#region Block conversions
			if (child.Name == "Block"):
				pattern = child.Attributes.GetNamedItem("Regex").Value
				name = child.InnerText
				Topomatic.Cad.View.ConsoleListner.Current.WriteLine(pattern)
				regex = System.Text.RegularExpressions.Regex(pattern)
				for i in xrange(drawing.Blocks.Count - 1, -1, -1):
					source = drawing.Blocks[i]
					if (not source.IsSystem):
						if (regex.IsMatch(source.Name)):
							rename_block(source, name)
					
			else:
				raise AssertionError(System.String.Format("Unknown block conversion element {0}", child.Name))
			#endregion
	if (abs(__scale - 1.0) > float.Epsilon):
		Topomatic.Cad.View.ConsoleListner.Current.WriteLine(__scale.ToString())
		if (__scale > 1.0):
			ps2 = round(__scale).ToString() + "g_"
		else:
			ps2 = "g" + round(__scale * 10.0).ToString() + "_"
		for i in xrange(drawing.Blocks.Count - 1, -1, -1):
			block = drawing.Blocks[i]
			name = block.Name
			if (name.startswith(ps1)):
				name = ps2 + name.Substring(len(ps1))
				rename_block(block, name)

@dlr.params(Topomatic.Dwg.Drawing, System.Xml.XmlElement)
def applay_styles_conversion(drawing, node):
	"""Переименование стилей в соответствии с параметрами из файла gugk.xml"""
	for child in node.ChildNodes:
		if (child.NodeType == System.Xml.XmlNodeType.Element):
			#region Style conversions
			if (child.Name == "Style"):
				pattern = child.Attributes.GetNamedItem("Regex").Value
				name = child.InnerText
				Topomatic.Cad.View.ConsoleListner.Current.WriteLine(pattern)
				regex = System.Text.RegularExpressions.Regex(pattern)
				for i in xrange(drawing.Styles.Count - 1, -1, -1):
					source = drawing.Styles[i]
					if (not source.IsSystem):
						if (regex.IsMatch(source.Name)):
							rename_style(source, name)
					
			else:
				raise AssertionError(System.String.Format("Unknown style conversion element {0}", child.Name))
			#endregion

@dlr.params(Topomatic.Dwg.Drawing, System.Xml.XmlElement)
def applay_linetypes_conversion(drawing, node):
	"""Переименование типов линий в соответствии с параметрами из файла gugk.xml"""
	for child in node.ChildNodes:
		if (child.NodeType == System.Xml.XmlNodeType.Element):
			#region Linetype conversions
			if (child.Name == "Linetype"):
				pattern = child.Attributes.GetNamedItem("Regex").Value
				name = child.InnerText
				Topomatic.Cad.View.ConsoleListner.Current.WriteLine(pattern)
				regex = System.Text.RegularExpressions.Regex(pattern)
				for i in xrange(drawing.Linetypes.Count - 1, -1, -1):
					source = drawing.Linetypes[i]
					if (not source.IsSystem):
						if (regex.IsMatch(source.Name)):
							rename_linetype(source, name)
					
			else:
				raise AssertionError(System.String.Format("Unknown linetype conversion element {0}", child.Name))
			#endregion
	if (abs(__scale - 1.0) > float.Epsilon):
		if (__scale > 1.0):
			ps2 = round(__scale).ToString() + "g_"
		else:
			ps2 = "g" + round(__scale * 10.0).ToString() + "_"
		idx = 0
		while idx < drawing.Linetypes.Count:
			linetype = drawing.Linetypes[idx]
			name = linetype.Name
			if (name.startswith(ps1)):
				name = ps2 + name.Substring(len(ps1))
				rename_linetype(linetype, name)
			idx += 1
			
def applay_blocks_colors(list, node):
	for e in list:
		if (isinstance(e, Topomatic.Dwg.Entities.DwgInsert)): # Вставка блока
			for child in node.ChildNodes:
				if (child.NodeType == System.Xml.XmlNodeType.Element):
					#region Block Colors
					if (child.Name == "Block"):
						pattern = child.Attributes.GetNamedItem("Regex").Value
						name = child.InnerText
						#Topomatic.Cad.View.ConsoleListner.Current.WriteLine(pattern)
						regex = System.Text.RegularExpressions.Regex(pattern)
						if (regex.IsMatch(e.Block.Name)):
							e.Color = Topomatic.Cad.Foundation.CadColor.FromCompressValue(System.Convert.ToInt32(name))
					#endregion
				
def set_default_properties(drawing, e):
	"""Присваиваем всем примитивам значения свойств 'Цвет', 'Тип линии' и 'Вес линии' отличными от 'по слою', 'по блоку' и 'по умолчанию'"""
	if ((e.Color == Topomatic.Cad.Foundation.CadColor.ByLayer) or (e.Color == Topomatic.Cad.Foundation.CadColor.ByBlock)):
		e.Color = Topomatic.Cad.Foundation.CadColor.White
	if ((e.Linetype == drawing.Linetypes.ByLayer) or (e.Linetype == drawing.Linetypes.ByBlock)):
		e.Linetype = drawing.Linetypes.Continuous
	if ((e.Lineweight == Topomatic.Dwg.Lineweight.ByLayer) or (e.Lineweight == Topomatic.Dwg.Lineweight.ByBlock) or (e.Lineweight == Topomatic.Dwg.Lineweight.Default)):
		if (isinstance(e, Topomatic.Dwg.Entities.DwgText)):
			e.Lineweight = Topomatic.Dwg.Lineweight.lw015
		else:
			e.Lineweight = Topomatic.Dwg.Lineweight.lw020
			
def correct_coord_cross(insert):
	if (insert.Block.Name == "g_012"):
		insert.Lineweight = Topomatic.Dwg.Lineweight.lw020
		
def move_44_layer_text_to_45(drawing, text):
	if (text.Layer.Name == "44_Крышки колодцев"):
		text.Layer = drawing.Layers["45_Номера колодцев"]
		if (text.Layer):
			Topomatic.Cad.View.ConsoleListner.Current.WriteLine(text.Layer.Name)

#def correct_polyline_global_weight(polyline):
#	polyline.Width = 0
			
def convert_entities_to_simple(collection, drawing, result):
	"""Разбиение примитивов на более простые в соответствие с требованиями ГУГК"""
	#drawing = collection.Drawing
	for e in collection:
		set_default_properties(drawing, e)
		if (isinstance(e, Topomatic.Dwg.Entities.DwgPolyline)): # Полилиния
#			correct_polyline_global_weight(e)
			e.Elevation = 0.0
			result.Add(e)
		elif (isinstance(e, Topomatic.Dwg.Entities.DwgInsert)): # Вставка блока
			correct_coord_cross(e)
			result.Add(e)
			for attr in e.Attribs:
				if ((attr.Flags & Topomatic.Dwg.AttributeFlags.Invisible) != Topomatic.Dwg.AttributeFlags.Invisible):
					attr.Flags = attr.Flags | Topomatic.Dwg.AttributeFlags.Invisible
					if (isinstance(attr, Topomatic.Dwg.Entities.DwgMAttrib)):
						text = Topomatic.Dwg.Entities.DwgMText()
					else:
						text = Topomatic.Dwg.Entities.DwgText()
					text.Assign(attr)
					text.Transform(e.Matrix)
					text.Position = Topomatic.Cad.Foundation.Vector3D(text.Position.Pos, e.Position.Z)
					text.Layer = e.Layer
	#				Topomatic.Cad.View.ConsoleListner.Current.WriteLine(e.Layer.Name)
					convert_entities_to_simple([ text ], drawing, result)
		elif (isinstance(e, Topomatic.Dwg.Entities.DwgText)): # Текст
			move_44_layer_text_to_45(drawing, e)
			result.Add(e)
		elif (isinstance(e, Topomatic.Dwg.Entities.DwgHatch)): # Штриховка
			result.Add(e)
		elif (isinstance(e, Topomatic.Dwg.Entities.DwgWipeout)): # Маскировка
			result.Add(e)
		elif (isinstance(e, Topomatic.Dwg.Entities.DwgMText)): # Многострочный текст
			list = System.Collections.Generic.List[Topomatic.Dwg.Entities.DwgEntity]()
			e.Break(list)
			convert_entities_to_simple(list, drawing, result)
		elif (isinstance(e, Topomatic.Dwg.Entities.DwgFace)): # Face
			result.Add(e)
		elif (isinstance(e, Topomatic.Dwg.Entities.DwgLine)): # Line
			e.StartPoint = e.StartPoint.Pos
			e.EndPoint = e.EndPoint.Pos
			result.Add(e)
		elif (isinstance(e, Topomatic.Dwg.Entities.DwgSolid)): # Solid
			result.Add(e)
		elif (isinstance(e, Topomatic.Dwg.Entities.DwgPolyline3D)): # Polyline3D
			for i in xrange(0, e.Count):
				e[i] = Topomatic.Cad.Foundation.Vector3D(e[i].Pos, 0.0)
			result.Add(e)
		elif (e.IsBreakable): # Составной примитив
			list = System.Collections.Generic.List[Topomatic.Dwg.Entities.DwgEntity]()
			e.Break(list)
			convert_entities_to_simple(list, drawing, result)
		elif (isinstance(e, Topomatic.Dwg.Entities.IPolylineConverter)): # Прообразуемый в полилинию
			convert_entities_to_simple([e.ToPolyline()], drawing, result)
		else:
			Topomatic.Cad.View.ConsoleListner.Current.WriteLine(str.Format("Unbreakable entity {0} skiped", e.ToString()))
			result.Add(e)
			
@dlr.params(Topomatic.Dwg.Drawing)			
def modify_justification(drawing):
	for block in drawing.Blocks:
		for e in block:
			if (isinstance(e, Topomatic.Dwg.Entities.DwgText)):
				if (e.Justify == Topomatic.Dwg.TextAlignment.BottomCenter):
					clr.Convert(e, Topomatic.Dwg.Entities.DwgText).Position = e.TextAlignmentPoint
					e.Position = e.TextAlignmentPoint
				elif (e.Justify == Topomatic.Dwg.TextAlignment.BottomLeft):
					pass
				elif (e.Justify == Topomatic.Dwg.TextAlignment.BottomRight):
					e.Position = e.TextAlignmentPoint
				elif (e.Justify == Topomatic.Dwg.TextAlignment.Center):
					e.Position = e.TextAlignmentPoint	
				elif (e.Justify == Topomatic.Dwg.TextAlignment.Fit):
					pass
				elif (e.Justify == Topomatic.Dwg.TextAlignment.Aligned):
					pass
				elif (e.Justify == Topomatic.Dwg.TextAlignment.Left):
					pass
				elif (e.Justify == Topomatic.Dwg.TextAlignment.Middle):
					e.Position = e.TextAlignmentPoint
				elif (e.Justify == Topomatic.Dwg.TextAlignment.MiddleCenter):
					e.Position = e.TextAlignmentPoint
				elif (e.Justify == Topomatic.Dwg.TextAlignment.MiddleLeft):
					e.Position = e.TextAlignmentPoint
				elif (e.Justify == Topomatic.Dwg.TextAlignment.MiddleRight):
					e.Position = e.TextAlignmentPoint
				elif (e.Justify == Topomatic.Dwg.TextAlignment.Right):
					e.Position = e.TextAlignmentPoint
				elif (e.Justify == Topomatic.Dwg.TextAlignment.TopCenter):
					e.Position = e.TextAlignmentPoint
				elif (e.Justify == Topomatic.Dwg.TextAlignment.TopLeft):
					e.Position = e.TextAlignmentPoint
				elif (e.Justify == Topomatic.Dwg.TextAlignment.TopRight):
					e.Position = e.TextAlignmentPoint
				e.Justify = Topomatic.Dwg.TextAlignment.Left

@dlr.params(Topomatic.Dwg.DwgBlock, str)
def execute(model, path):
	#region Convert entities to simple
	for i in xrange(0, model.Drawing.Blocks.Count):
		blk = model.Drawing.Blocks[i]
		list = System.Collections.Generic.List[Topomatic.Dwg.Entities.DwgEntity](blk.Count)
		convert_entities_to_simple(blk, model.Drawing, list)
		#applay_blocks_colors(list, colors_node)
		blk.Entities.Clear()
		for e in list:
			blk.Add(e)
	#endregion
	#region Applay xml conversion document
	conversionXml = System.IO.Path.ChangeExtension(path, ".xml")
	xml = System.Xml.XmlDocument()
	xml.Load(conversionXml)
	conversions = xml.DocumentElement
	if (conversions.Name != "Conversions"):
		raise AssertionError(System.String.Format("Invalid xml conversions document \"{0}\"\r\n\"Conversions\" root node not found.", conversionXml))
	for node in conversions.ChildNodes:
		if (node.NodeType == System.Xml.XmlNodeType.Element):
			if node.Name == "LayersConversion":
				applay_layers_conversion(model.Drawing, node)
			elif node.Name == "BlocksConversion":
				applay_blocks_conversion(model.Drawing, node)
			#elif node.Name == "BlocksColors":
			#	colors_node = node
				#applay_blocks_colors(model.Drawing, node)
			elif node.Name == "StylesConversion":
				applay_styles_conversion(model.Drawing, node)
			elif node.Name == "LinetypesConversion":
				applay_linetypes_conversion(model.Drawing, node)
	#endregion
	#region Modify text justification
	modify_justification(model.Drawing)
	#endregion

if (__model != None):
	execute(__model, __path);
else:
	raise AssertionError("\"__model\" variable is not defined")
