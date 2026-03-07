class_name GlobalStateEntry
extends RefCounted

enum Kind { FLAG, VARIABLE }

var id: String
var name: String
var kind: Kind
var value_type: String 
var value: Variant
