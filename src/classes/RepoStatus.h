#ifndef RepoStatus_h
#define RepoStatus_h

#include <deque>
#include <map>
#include <set>
#include <string>

typedef std::map<std::string, int> FileStatusMap;
class FileNameSet : public std::set<std::string>
{
public:
	std::deque<std::string> getPathSpecMatches(const PathString& spec);
};

class RepoStatus : public GitLinkSuperClass
{
public:
	RepoStatus(GitLinkRepository& repo, bool doRenames, bool includeIgnored = false, bool recurseUntrackedDirs = false);

	bool isValid() { return isValid_; };
	void updateStatus();
	void writeStatus(MLINK lnk);
	bool fileChanged(const std::string& filePath);
	void convertFileNamesToLower(WolframLibraryData libData);
	FileNameSet allFileNames();

private:
	bool isValid_;
	bool doRenames_;
	bool includeIgnored_;
	bool recurseUntrackedDirs_;
	GitLinkRepository& repo_;
	FileStatusMap indexStatus_;
	FileStatusMap workingTreeStatus_;


	void writeFiles_(MLHelper& helper, const char* keyName, git_status_t status);

	static int statusCallback_(const char* path, unsigned int status_flags, void* payload);
};

#endif // RepoStatus_h
