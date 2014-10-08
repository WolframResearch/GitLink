(* ::Package:: *)

Needs["CCompilerDriver`"]
base = ParentDirectory[NotebookDirectory[]];
src = FileNames["*.cpp", FileNameJoin[{base, "src"}], Infinity];
srcDirs = Select[FileNames["*", FileNameJoin[{base, "src"}]], DirectoryQ];


component = FileNameJoin[{ParentDirectory[base], "Components", "libgit2", "0.21.1"}];
libDirs = {FileNameJoin[{component, $SystemID}]};
includeDir = FileNameJoin[{component, "Source", "include"}];
compileOpts = "";


compileOpts = Switch[$OperatingSystem,
	"Windows", "/MT /EHsc",
	_, ""];
linkerOpts = Switch[$OperatingSystem,
	"Windows", "/NODEFAULTLIB:msvcrt",
	_, ""];
oslibs = Switch[$OperatingSystem,
	"Windows", {"advapi32", "ole32", "user32"},
	"MacOSX", {"ssl", "z", "iconv", "ssh2", "crypto"},
	_, {}
];


destDir = FileNameJoin[{base, "gitLink", "LibraryResources", $SystemID}];
If[!DirectoryQ[destDir], CreateDirectory[destDir]];


lib = CreateLibrary[src, "gitLink",
(*	"ShellOutputFunction"\[Rule]Print,*)
	"TargetDirectory"->destDir,
	"Language"->"C++",
	"CompileOptions"->compileOpts,
	"LinkerOptions"->linkerOpts,
	"IncludeDirectories"->Flatten[{includeDir, srcDirs}],
	"LibraryDirectories"->libDirs,
	"Libraries"->Prepend[oslibs, "git2"]
]


If[!MemberQ[$LibraryPath, destDir], PrependTo[$LibraryPath, destDir]];
