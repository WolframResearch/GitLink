(* ::Package:: *)

Needs["GitLink`"];
$TestRepos = FileNameJoin[{NotebookDirectory[], "repos"}];
$RepoDirectory = FileNameJoin[{$TemporaryDirectory, "Range"}];
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
(*Test GitAheadBehind*)


VerificationTest[
	{
		GitAheadBehind[$Repo, "master", "origin/master"] === {0,0}
		, GitAheadBehind[$Repo, "origin/master", "origin/dir"] === {3,3}
		, GitAheadBehind[ToGitObject["master", $Repo], ToGitObject["origin/dir", $Repo]] === {3,3}
	},
	{True, True, True}
]


VerificationTest[
	GitAheadBehind[$Repo, "master", "nonexistent"],
	$Failed,
	GitAheadBehind::badcommitish
]


ResetDirectory[];
GitClose[$Repo];
DeleteDirectory[$RepoDirectory, DeleteContents->True];
