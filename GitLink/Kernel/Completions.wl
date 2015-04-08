(* ::Package:: *)

BeginPackage["GitLink`Completions`"];
Begin["`Private`"];


(*

	Numeric codes are for certain special types of completions. Zero means 'don't complete':
	
	Normal argument     0
	AbsoluteFilename    2
	RelativeFilename    3
	Color               4
	PackageName         7
	DirectoryName       8
	InterpreterType     9

*)



specialArgCompletionsList =
{
	"GitClone" -> {0, 8},
	"GitInit" -> {8},
	"GitOpen" -> {8},
	"GitRepoQ" -> {8}
};


If[$Notebooks && Internal`CachedSystemInformation["FrontEnd", "VersionNumber"] > 10.0,
	Scan[
		FE`Evaluate[FEPrivate`AddSpecialArgCompletion[#]]&,
		specialArgCompletionsList
	]
]


End[];
EndPackage[];
