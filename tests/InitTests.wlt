BeginTestSection["InitTests"]

VerificationTest[(* 1 *)
	gitInitBlock[GitProperties[$Repo, List["ShallowQ", "BareQ", "DetachedHeadQ", "Conflicts", "Remotes", "LocalBranches", "RemoteBranches"]]]
	,
	List[False, False, False, List[], Association[], List[], List[]]	
]

VerificationTest[(* 2 *)
	gitInitBlock[GitProperties[$Repo, List["ShallowQ", "BareQ", "DetachedHeadQ", "Conflicts", "Remotes", "LocalBranches", "RemoteBranches", "WorkingDirectory"]], Rule["Bare", True]]
	,
	List[False, True, False, List[], Association[], List[], List[], None]	
]

EndTestSection[]
