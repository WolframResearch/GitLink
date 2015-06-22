(* ::Package:: *)

Needs["GitLink`"];
$TestRepos = FileNameJoin[{NotebookDirectory[], "repos"}];
$RepoDirectory = FileNameJoin[{$TemporaryDirectory, "AddResetTestRepo"}];
Quiet[DeleteDirectory[$RepoDirectory, DeleteContents->True]];
$Repo = GitClone[FileNameJoin[{$TestRepos, "testrepo", ".gitted"}], $RepoDirectory];
SetDirectory[$RepoDirectory];
changefile[filename_] := Module[{strm = OpenAppend[filename]},
	WriteString[strm, "\nnew line\n"]; Close[strm]];
fullpath[path_] := FileNameJoin[{$RepoDirectory, path}]


VerificationTest[
	{
		GitRepoQ[$RepoDirectory]
		, AssociationQ[GitProperties[$Repo]]
		, Flatten[Values[GitStatus[$Repo]]] === {}
	},
	{True, True, True}
]


(* ::Subsubsection:: *)
(*Add a new file*)


VerificationTest[
	Export["newfile.txt", Range[5], "Text"];
	{
		GitAdd[$Repo, "newfile.txt"] === {fullpath["newfile.txt"]}
		, GitStatus[$Repo]["IndexNew"] === {"newfile.txt"}
	},
	{True, True}
]


(* ::Subsubsection:: *)
(*Reset the file*)


VerificationTest[
	{
		GitReset[$Repo, "newfile.txt"] === {fullpath["newfile.txt"]}
		, GitStatus[$Repo]["IndexNew"] === {}
	},
	{True, True}
]


(* ::Subsubsection:: *)
(*Add a directory*)


VerificationTest[
	CreateDirectory["newdir"];
	filelist = FileNameJoin[{$RepoDirectory, "newdir", #}]& /@ {"abc.txt", "def.txt"};
	Scan[Export[#, "abc", "Text"]&, filelist];

	{
		GitAdd[$Repo, "newdir"] === filelist;
		, Sort[GitStatus[$Repo]["IndexNew"]] === Sort[filelist]
	}
	,
	{True, True}
]


(* ::Subsubsection:: *)
(*Reset the directory*)


VerificationTest[
	{
		Sort[GitReset[$Repo, "newdir"]] === Sort[filelist];
		, GitStatus[$Repo]["IndexNew"] === {}
	}
	,
	{True, True}
]


(* ::Subsubsection:: *)
(*Add a change*)


VerificationTest[
	changefile["new.txt"];

	{
		GitAdd[$Repo, "new.txt"] === fullpath["new.txt"]
		, GitStatus[$Repo]["IndexModified"] === {fullpath["new.txt"]}
	}
	,
	{True, True}
]


(* ::Subsubsection:: *)
(*Reset a change*)


VerificationTest[
	{
		GitReset[$Repo, "new.txt"]] === fullpath["new.txt"];
		, GitStatus[$Repo]["IndexModified"] === {}
	}
	,
	{True, True}
]


(* ::Subsubsection:: *)
(*Add a deletion*)


VerificationTest[
	DeleteFile["README"];

	{
		GitStatus[$Repo][[{"Deleted", "IndexDeleted"}]] === {{"README"}, {}}
		, GitAdd[$Repo, "README"] === FileNameJoin[{$RepoDirectory, "README"}]
		, GitStatus[$Repo][[{"Deleted", "IndexDeleted"}]] === {{}, {"README"}}
	}
	,
	{True, True, True}
]


(* ::Subsubsection:: *)
(*Reset a deletion*)


VerificationTest[
	{
		GitReset[$Repo, "README"] === fullpath["README"]
		, GitStatus[$Repo][["IndexDeleted"]] === {}
	}
	,
	{True, True}
]


(* ::Subsubsection:: *)
(*Add a change to a new file*)


VerificationTest[
	GitAdd[$Repo, "newfile.txt"];
	changefile["newfile.txt"];

	{
		GitStatus[$Repo][[{"Modified", "IndexNew"}]] === {{"newfile.txt"}, {"newfile.txt"}}
		, GitAdd[$Repo, "newfile.txt"] === FileNameJoin[{$RepoDirectory, "newfile.txt"}]
		, GitStatus[$Repo][["Modified", "IndexNew"}]] === {{}, {"newfile.txt"}}
	}
	,
	{True, True, True}
]


ResetDirectory[];
GitClose[$Repo];
DeleteDirectory[$RepoDirectory, DeleteContents->True];
