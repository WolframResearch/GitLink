(* ::Package:: *)

Needs["CCompilerDriver`"]
base = ParentDirectory[NotebookDirectory[]];
component = FileNameJoin[{ParentDirectory[base], "Components", "libgit2", "0.21.1"}];
src = FileNames["*.cpp", FileNameJoin[{base, "src"}], Infinity];
srcDirs = Select[FileNames["*", FileNameJoin[{base, "src"}]], DirectoryQ];
libDir = FileNameJoin[{component, $SystemID}];
includeDir = FileNameJoin[{component, "Source", "include"}];
destDir = FileNameJoin[{base, "LibraryResources", $SystemID}];
If[!DirectoryQ[destDir], CreateDirectory[destDir]];
oslibs = Switch[$OperatingSystem,
	"Windows", {"advapi32", "ole32"},
	"MacOSX", {},
	_, {}
];


lib = CreateLibrary[src, "gitLink",
	"TargetDirectory"->destDir,
	"Language"->"C++",
	"IncludeDirectories"->Flatten[{includeDir, srcDirs}],
	"LibraryDirectories"->{libDir},
	"Libraries"->Prepend[oslibs, "git2"]
]


If[!MemberQ[$LibraryPath, destDir], PrependTo[$LibraryPath, destDir]];
