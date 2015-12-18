(* ::Package:: *)

Needs["GitLink`"];
$TestRepos = FileNameJoin[{NotebookDirectory[], "repos"}];
$RepoDirectory = FileNameJoin[{$TemporaryDirectory, "Branch"}];
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
(*Create and delete a branch*)


VerificationTest[
	{
		GitCreateBranch[$Repo, "branch1"]
		, GitBranchQ[$Repo, "branch1"]
		, GitDeleteBranch[$Repo, "branch1"] === Null
		, !GitBranchQ[$Repo, "branch1"]
	},
	{True, True, True, True}
]


(* ::Subsubsection:: *)
(*Test setting upstream branch*)


VerificationTest[
	{
		GitSetUpstreamBranch[$Repo, "master", "origin/master"]
		, !GitSetUpstreamBranch[$Repo, "master", "origin/dir"]
		, GitUpstreamBranch[$Repo, "master"] === "origin/master"
	},
	{True, True, True}
]


VerificationTest[
	{
		GitSetUpstreamBranch[$Repo, "master", "origin/dir", "Force"->True]
		, GitUpstreamBranch[$Repo, "master"] === "origin/dir"
		, GitSetUpstreamBranch[$Repo, "master", "origin/master", "Force"->True]
	},
	{True, True, True}
]


ResetDirectory[];
GitClose[$Repo];
DeleteDirectory[$RepoDirectory, DeleteContents->True];
