(* ::Package:: *)

BeginTestSection["InitTests"]


Needs["GitLink`"];
$RepoRootDirectory = FileNameJoin[{$TemporaryDirectory, "InitRepos"}];
Quiet[DeleteDirectory[$RepoRootDirectory, DeleteContents->True]];
Quiet[CreateDirectory[$RepoRootDirectory]];
SetAttributes[gitInitBlock,HoldFirst];
gitInitBlock[code_,opts___]:=
	Block[{result, $Repo, $RepoDirectory},
		$RepoDirectory = FileNameJoin[{AbsoluteFileName[$RepoRootDirectory],"InitTestRepo"}];
		$Repo=GitInit[$RepoDirectory,opts];
		result=code;
		GitClose[$Repo];
		DeleteDirectory[$RepoDirectory,DeleteContents->True];
		result
	]


VerificationTest[
	gitInitBlock[GitProperties[$Repo, List["ShallowQ", "BareQ", "DetachedHeadQ", "Conflicts", "Remotes", "LocalBranches", "RemoteBranches"]]]
	,
	{False, False, False, {}, Association[], {}, {}}	
]


VerificationTest[
	gitInitBlock[GitProperties[$Repo, List["ShallowQ", "BareQ", "DetachedHeadQ", "Conflicts", "Remotes", "LocalBranches", "RemoteBranches", "WorkingDirectory"]], Rule["Bare", True]]
	,
	{False, True, False, {}, Association[], {}, {}, None}	
]


VerificationTest[
	gitInitBlock[SameQ[GitOpen[$RepoDirectory], $Repo]]
	,
	True	
]


EndTestSection[]
