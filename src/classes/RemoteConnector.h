#ifndef RemoteConnector_h_
#define RemoteConnector_h_ 1

#include "git2.h"

/// Manages all of the connectors in libgit2, including all of the callbacks.
class RemoteConnector
{
public:
	RemoteConnector(const char* theKeyFile);
	RemoteConnector(const RemoteConnector& connector);
	~RemoteConnector();
	RemoteConnector& operator=(const RemoteConnector& connector);

	const char* keyFile() const { return keyFile_; };

	bool fetch(git_remote* remote) { return connect_(remote, GIT_DIRECTION_FETCH); };
	bool push(git_remote* remote) { return connect_(remote, GIT_DIRECTION_PUSH); };
	bool clone(git_repository** repo, const char* uri, const char* localPath, git_clone_options* options);

private:
	static int AcquireCredsCallBack(git_cred** cred,const char* url,const char *username,unsigned int allowed_types, void* payload);
	int acquireCredsCallBack_(git_cred** cred, const char* url, const char* username, unsigned int allowed_types);

	bool connect_(git_remote* remote, git_direction direction);

	bool checkForSshAgent_;
	const char* keyFile_;
	git_remote_callbacks callbacks_;
};

#endif // RemoteConnector_h_
