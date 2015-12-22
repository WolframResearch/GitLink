(* ::Package:: *)

BeginTestSection["Push"]


Needs["GitLink`"];
$TestRepos = FileNameJoin[{NotebookDirectory[], "repos"}];
$RepoDirectory = FileNameJoin[{$TemporaryDirectory, "PushTestRepo"}];
$LocalDestRepoDir = FileNameJoin[{$TemporaryDirectory, "DestRepo"}];
$RemoteDestRepoURI = "ssh://git@stash.wolfram.com:7999/~jfultz/pushunittest.git";
Quiet[DeleteDirectory[$RepoDirectory, DeleteContents->True]];
$Repo = GitClone[FileNameJoin[{$TestRepos, "testrepo", ".gitted"}], $RepoDirectory];
Quiet[DeleteDirectory[$LocalDestRepoDir, DeleteContents->True]];


VerificationTest[
	GitRepoQ[$RepoDirectory] && AssociationQ[GitProperties[$Repo]]
]


(* ::Text:: *)
(*Push to an empty local repo*)


VerificationTest[
	repo2 = GitInit[$LocalDestRepoDir, "Bare"->True];
	GitAddRemote[$Repo, "localdest", $LocalDestRepoDir];

	GitPush[$Repo, "localdest", "refs/heads/master:refs/heads/master"]
	&& GitSHA[$Repo, "master"] === GitSHA[repo2, "master"]
]
GitClose[repo2]


(* ::Text:: *)
(*Push to a remote repo (force push to a known state)*)


VerificationTest[
	GitAddRemote[$Repo, "remotedest", $RemoteDestRepoURI];

	GitPush[$Repo, "remotedest","+refs/heads/master:refs/heads/master"]
	&& GitSHA[$Repo, "master"] === GitSHA[$Repo, "remotedest/master"]
]
sha = GitSHA[$Repo, "Master"];


(* ::Text:: *)
(*Push a normal commit*)


VerificationTest[
	commit = GitCommit[$Repo, "push unit test",
				GitProperties[ToGitObject[$Repo,"master"]]["Tree"], {"master"}];
	GitPush[$Repo, "remotedest","refs/heads/master:refs/heads/master"]
	&& GitSHA[commit] === GitSHA[$Repo, "remotedest/master"]
]


(* ::Text:: *)
(*Force push back to previous state*)


VerificationTest[
	GitCheckoutReference[$Repo, sha];
	GitPush[$Repo, "remotedest", "+HEAD:refs/heads/master"]
	&& sha === GitSHA[$Repo, "remotedest/master"]
]


GitClose[$Repo];
DeleteDirectory[$RepoDirectory, DeleteContents->True];


EndTestSection[]
