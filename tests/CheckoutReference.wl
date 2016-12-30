(* ::Package:: *)

Needs["GitLink`"];
$TestRepos = FileNameJoin[{NotebookDirectory[], "repos"}];
$RepoDirectory = FileNameJoin[{$TemporaryDirectory, "CheckoutReferenceRepo"}];
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
(*Check out branch at same position*)


VerificationTest[
	{
		GitCreateBranch[$Repo, "test_branch", "Force"->True]
		, GitCheckoutReference[$Repo, "test_branch"] === ToGitObject[$Repo, "master"]
		, ToGitObject[$Repo, "HEAD"] === ToGitObject[$Repo, "master"]
		, Join @@ Values[GitStatus[$Repo]] === {}
		, GitCheckoutReference[$Repo, "master"] === ToGitObject[$Repo, "master"]
	},
	{True, True, True, True, True}
]


(* ::Subsubsection:: *)
(*Check out branch at a different position*)


VerificationTest[
	{
		GitCreateBranch[$Repo, "test_branch", "master~3", "Force"->True]
		, GitCheckoutReference[$Repo, "test_branch"] === ToGitObject[$Repo, "master~3"]
		, ToGitObject[$Repo, "HEAD"] === ToGitObject[$Repo, "master~3"]
		, Join @@ Values[GitStatus[$Repo]] === {}
		, GitCheckoutReference[$Repo, "master"] === ToGitObject[$Repo, "master"]
		, Join @@ Values[GitStatus[$Repo]] === {}
	},
	{True, True, True, True, True, True}
]


(* ::Subsubsection:: *)
(*Changing a file which doesn't change between refs doesn't prevent a checkout*)


VerificationTest[
	changefile["new.txt"];
	{
		GitCreateBranch[$Repo, "test_branch", "master~3", "Force"->True]
		, GitCheckoutReference[$Repo, "test_branch"] === ToGitObject[$Repo, "master~3"]
		, ToGitObject[$Repo, "HEAD"] === ToGitObject[$Repo, "master~3"]
		, GitStatus[$Repo]["Modified"] === {"new.txt"}
		, GitCheckoutReference[$Repo, "master"] === ToGitObject[$Repo, "master"]
		, GitStatus[$Repo]["Modified"] === {"new.txt"}
	},
	{True, True, True, True, True, True}
]


GitClose[$Repo];
DeleteDirectory[$RepoDirectory, DeleteContents->True];


EndTestSection[]
