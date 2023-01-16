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


def applay_by_block(block):
	byBlock = Topomatic.Cad.Foundation.CadColor.FromCompressValue(0)
	for e in block:
		e.Color = byBlock
		if (isinstance(e, Topomatic.Dwg.Entities.DwgInsert)):
			blk = e.Block
			if blk != None:
				applay_by_block(blk)


@dlr.params(Topomatic.Dwg.Drawing, System.Xml.XmlElement)
def applay_layers_conversion(drawing, node):
	"""Переименование слоев в соответствии с параметрами из файла gugk.xml"""
	bmap = set()
	name = node.Attributes.GetNamedItem("Name").Value
	state = drawing.LayerStates[name]
	if state == None:
		state = drawing.LayerStates.Add(name, "")
	state.RestoreLayerProperties = Topomatic.Dwg.RestoreLayerPropertiesFlags.Color
	byLayer = Topomatic.Cad.Foundation.CadColor.FromCompressValue(256)
	byBlock = Topomatic.Cad.Foundation.CadColor.FromCompressValue(0)
	model = drawing.Blocks.ModelSpace
	for child in node.ChildNodes:
		if (child.NodeType == System.Xml.XmlNodeType.Element):
			if (child.Name == "Layer"):
				pattern = None
				regexNode = child.Attributes.GetNamedItem("Regex")
				if (regexNode != None):
					pattern = regexNode.Value
				color = Topomatic.Cad.Foundation.CadColor.FromCompressValue(int(child.InnerText))
				if (not str.IsNullOrEmpty(pattern)):
					regex = System.Text.RegularExpressions.Regex(pattern)
					for i in xrange(drawing.Layers.Count - 1, -1, -1):
						source = drawing.Layers[i]
						if (regex.IsMatch(source.Name)):
							source.Color = color
							state.Add(source.Name).Color = color
							for i in xrange(0, model.Count):
								if (model[i].Layer == source):
									model[i].Color = byLayer
									if (isinstance(model[i], Topomatic.Dwg.Entities.DwgInsert)):
										blk = model[i].Block
										if blk != None:
											if not blk in bmap:
												bmap.add(blk)
												applay_by_block(blk)
			else:
				raise AssertionError(System.String.Format("Unknown layer conversion element {0}", child.Name))

@dlr.params(Topomatic.Dwg.DwgBlock, str)
def execute(model, path):
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
	#endregion

if (__model != None):
	execute(__model, __path);
else:
	raise AssertionError("\"__model\" variable is not defined")
