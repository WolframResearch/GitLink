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
#include "GitLinkRepository.h"
#include "GitLinkCommit.h"
#include "Message.h"


EXTERN_C DLLEXPORT int GitPush(WolframLibraryData libData, MLINK lnk)
{
	bool success = false;
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString remote(lnk);
	MLString credentialsFile(lnk);
	MLString branch(lnk);

	repo.push(lnk, remote, credentialsFile, branch);

	return LIBRARY_NO_ERROR;
}
