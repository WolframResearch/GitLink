/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include "mathlink.h"
#include "WolframLibrary.h"
#include "git2.h"
#include "RepoInterface.h"
#include "GitLinkRepository.h"

GitLinkRepository::GitLinkRepository(WolframLibraryData libData, mint Argc, MArgument* Argv, int repoArg) :
	key_(BAD_KEY), repo_(NULL)
{
	if (Argc > repoArg)
	{
		char* repoPath = MArgument_getUTF8String(Argv[repoArg]);
		if (repoPath != NULL)
		{
			if (git_repository_open(&repo_, repoPath) != 0)
			{
				git_repository_free(repo_);
				repo_ = NULL;
			}
			libData->UTF8String_disown(repoPath);
		}
	}
}

GitLinkRepository::GitLinkRepository(MLINK lnk) :
	key_(BAD_KEY), repo_(NULL)
{
	switch (MLGetType(lnk))
	{
		case MLTKINT:
			MLGetInteger64(lnk, &key_);
			repo_ = ManagedRepoMap[key_];
			break;

		case MLTKSTR:
		{
			const unsigned char* str;
			int numBytes;
			MLGetUTF8String(lnk, &str, &numBytes, NULL);
			if (git_repository_open(&repo_, (char*) str) != 0)
			{
				git_repository_free(repo_);
				repo_ = NULL;
			}
			MLReleaseUTF8String(lnk, str, numBytes);
			break;
		}
		default:
			break;
	}
}

GitLinkRepository::GitLinkRepository(mint key) :
	key_(key), repo_(ManagedRepoMap[key])
{
}


GitLinkRepository::~GitLinkRepository()
{
	if (key_ == BAD_KEY && repo_ != NULL)
		git_repository_free(repo_);
}

void GitLinkRepository::setKey(mint key)
{
	key_ = key;
	ManagedRepoMap[key] = repo_;
}

void GitLinkRepository::unsetKey()
{
	ManagedRepoMap.erase(key_);
	key_ = BAD_KEY;
}
