/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#ifndef GitLinkRepository_h_
#define GitLinkRepository_h_ 1

const mint BAD_KEY = -1;

class GitLinkRepository
{
public:
	GitLinkRepository(WolframLibraryData libData, mint Argc, MArgument* Argv, int repoArg = 0);
	GitLinkRepository(mint key);
	GitLinkRepository(MLINK link);
	~GitLinkRepository();

	bool isValid() const { return repo_ != NULL; };

	mint key() const { return key_; };
	void setKey(mint key) { key_ = key; };
	void unsetKey() { key_ = BAD_KEY; };

	git_repository* repo() { return repo_; };

private:
	git_repository* repo_;
	mint key_;
};

#endif // GitLinkRepository_h_
