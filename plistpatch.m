#include <Foundation/Foundation.h>
#include <xpc/xpc.h>
#include <sys/stat.h>
#include <assert.h>
#include <roothide.h>
#include "launchctl.h"

#ifndef DEBUG
#undef printf
#define printf(...)
#endif

NSObject* xpc_convert_to_nsobj(xpc_object_t in)
{
	// for (int i = 0; i < level; i++)
	// 	putchar('\t');

	// if (name != NULL)
	// 	printf("\"%s\" = ", name);

	xpc_type_t t = xpc_get_type(in);

	if (t == XPC_TYPE_STRING) {
		printf("\"%s\";\n", xpc_string_get_string_ptr(in));
        return @(xpc_string_get_string_ptr(in));
    }
	else if (t == XPC_TYPE_INT64) {
		printf("%lld;\n", xpc_int64_get_value(in));
        return @(xpc_int64_get_value(in));
    }
	else if (t == XPC_TYPE_DOUBLE) {
		printf("%f;\n", xpc_double_get_value(in));
        return @(xpc_double_get_value(in));
    }
	else if (t == XPC_TYPE_BOOL) {
		if (in == XPC_BOOL_TRUE) {
			printf("true;\n");
            return @YES;
        }
		else if (in == XPC_BOOL_FALSE) {
			printf("false;\n");
            return @NO;
        }
	} 
    // else if (t == XPC_TYPE_MACH_SEND)
	// 	printf("mach-port-object;\n");
	// else if (t == XPC_TYPE_FD)
	// 	printf("file-descriptor-object;\n");
	else if (t == XPC_TYPE_ARRAY) {
        NSMutableArray* nsarr = [[NSMutableArray alloc] init];
        
		printf("(\n");
		int c = xpc_array_get_count(in);
		for (int i = 0; i < c; i++) {
			NSObject* obj = xpc_convert_to_nsobj(xpc_array_get_value(in, i));
            [nsarr addObject:obj];
		}
		// for (int i = 0; i < level; i++)
		// 	putchar('\t');
		printf(");\n");

        return nsarr;
	} else if (t == XPC_TYPE_DICTIONARY) {
        NSMutableDictionary* nsdict = [[NSMutableDictionary alloc] init];

		printf("{\n");
		// int __block blevel = level + 1;
		(void)xpc_dictionary_apply(in, ^ bool (const char *key, xpc_object_t value) {
		        printf("\"%s\" = ", key);
				NSObject* obj = xpc_convert_to_nsobj(value);
                nsdict[@(key)] = obj;
				return true;
		});
		// for (int i = 0; i < level; i++)
		// 	putchar('\t');
		printf("};\n");

        return nsdict;
	}

	assert(in == NULL);
	return nil;
}

void xpc_save_to_file(xpc_object_t object, const char* path)
{
    printf("xpc_save_to_file to %s\n", path);
    NSObject* nsobj = xpc_convert_to_nsobj(object);

    assert([nsobj isKindOfClass:NSMutableDictionary.class]);
    
    NSMutableDictionary* dict = (NSMutableDictionary*)nsobj;
    if(![dict writeToFile:@(jbroot(path)) atomically:YES]) {
		fprintf(stderr, "failed to patch plist: %s\n", path);
		abort();
	}
}

#ifndef __GNUC__
#define __GNUC__
#endif
#include <assert.h>
void patch_plist_file(const char* path)
{
	if(strncmp(path, "/rootfs/", sizeof("/rootfs/")-1)==0) {
		printf("daemon in rootfs: %s\n", path);
		return;
	}

	xpc_object_t service = launchctl_xpc_from_plist(path);
	if(!service) return;

	bool patched = xpc_dictionary_get_bool(service, "__Patched");
	
	const char* Program = xpc_dictionary_get_string(service, "Program");
	if(Program)
	{
		assert(Program[0] == '/');

		if(strncmp(Program, "/rootfs/", sizeof("/rootfs/")-1)==0) {
			printf("daemon in rootfs: %s\n", Program);
			return;
		}

		if(patched) Program = rootfs(Program);
		xpc_dictionary_set_string(service, "Program", jbroot(Program));
	}
	else
	{
		xpc_object_t ProgramArguments = xpc_dictionary_get_array(service, "ProgramArguments");
		if(ProgramArguments) {
			assert(xpc_array_get_count(ProgramArguments) > 0);

			const char* arg0 = xpc_array_get_string(ProgramArguments, 0);

			assert(arg0 && arg0[0]=='/');

			if(strncmp(arg0, "/rootfs/", sizeof("/rootfs/")-1)==0) {
				printf("daemon in rootfs: %s\n", arg0);
				return;
			}

			if(patched) arg0 = rootfs(arg0);
			xpc_array_set_string(ProgramArguments, 0, jbroot(arg0));
		}
	}

	const char* RootDirectory = xpc_dictionary_get_string(service, "RootDirectory");
	if(RootDirectory) {
		assert(RootDirectory[0] == '/');
		if(patched) RootDirectory = rootfs(RootDirectory);
		xpc_dictionary_set_string(service, "RootDirectory", jbroot(RootDirectory));
	}

	const char* WorkingDirectory = xpc_dictionary_get_string(service, "WorkingDirectory");
	if(WorkingDirectory) {
		assert(WorkingDirectory[0] == '/');
		if(patched) WorkingDirectory = rootfs(WorkingDirectory);
		xpc_dictionary_set_string(service, "WorkingDirectory", jbroot(WorkingDirectory));
	}

	const char* StandardInPath = xpc_dictionary_get_string(service, "StandardInPath");
	if(StandardInPath) {
		assert(StandardInPath[0] == '/');
		if(patched) StandardInPath = rootfs(StandardInPath);
		xpc_dictionary_set_string(service, "StandardInPath", jbroot(StandardInPath));
	}

	const char* StandardOutPath = xpc_dictionary_get_string(service, "StandardOutPath");
	if(StandardOutPath) {
		assert(StandardOutPath[0] == '/');
		if(patched) StandardOutPath = rootfs(StandardOutPath);
		xpc_dictionary_set_string(service, "StandardOutPath", jbroot(StandardOutPath));
	}

	const char* StandardErrorPath = xpc_dictionary_get_string(service, "StandardErrorPath");
	if(StandardErrorPath) {
		assert(StandardErrorPath[0] == '/');
		if(patched) StandardErrorPath = rootfs(StandardErrorPath);
		xpc_dictionary_set_string(service, "StandardErrorPath", jbroot(StandardErrorPath));
	}

	xpc_object_t WatchPaths = xpc_dictionary_get_array(service, "WatchPaths");
	for(int i = 0; i < xpc_array_get_count(WatchPaths); i++) {
		const char* Path = xpc_array_get_string(WatchPaths, i);
		assert(Path[0] == '/');
		if(patched) Path = rootfs(Path);
		printf("WatchPaths[%d] %s\n", i, Path);
		xpc_array_set_string(WatchPaths, i, jbroot(Path));
	}

	xpc_object_t QueueDirectories = xpc_dictionary_get_array(service, "QueueDirectories");
	for(int i = 0; i < xpc_array_get_count(QueueDirectories); i++) {
		const char* Path = xpc_array_get_string(QueueDirectories, i);
		assert(Path[0] == '/');
		if(patched) Path = rootfs(Path);
		printf("QueueDirectories[%d] %s\n", i, Path);
		xpc_array_set_string(QueueDirectories, i, jbroot(Path));
	}

	xpc_object_t EnvironmentVariables = xpc_dictionary_get_dictionary(service, "EnvironmentVariables");
	if(EnvironmentVariables) {
		xpc_object_t new_EnvironmentVariables = xpc_dictionary_create(NULL, NULL, 0);
		xpc_dictionary_apply(xpc_copy(EnvironmentVariables), ^bool(const char* key, xpc_object_t value) {
			
			static const char* StockPathEnvs[] = {
				"CFFIXED_USER_HOME",
				"HOME",
				"TMPDIR",
			};

			for(int i=0; i<sizeof(StockPathEnvs)/sizeof(StockPathEnvs[0]); i++) {
				if(strcmp(key, StockPathEnvs[i]) == 0) {
					const char* path = xpc_string_get_string_ptr(value);
					assert(path[0] == '/');
					if(patched) path = rootfs(path);
					printf("EnvironmentVariables[%d] %s\n", i, path);
					xpc_dictionary_set_string(EnvironmentVariables, key, jbroot(path));
					break;
				}
			}

			return true;
		});
	}

	xpc_object_t KeepAlive = xpc_dictionary_get_value(service, "KeepAlive");
	if(xpc_get_type(KeepAlive)==XPC_TYPE_DICTIONARY) {
		xpc_object_t PathState = xpc_dictionary_get_dictionary(KeepAlive, "PathState");
		if(PathState) {
			xpc_object_t new_PathState = xpc_dictionary_create(NULL, NULL, 0);
			xpc_dictionary_apply(xpc_copy(PathState), ^bool(const char* key, xpc_object_t value) {
				
				assert(key[0] == '/');

				if(patched) key = rootfs(key);

				printf("KeepAlive.PathState: %s\n", key);

				xpc_dictionary_set_value(new_PathState, jbroot(key), value);

				return true;
			});
			xpc_dictionary_set_value(KeepAlive, "PathState", new_PathState);
		}
	}

	xpc_object_t Sockets = xpc_dictionary_get_dictionary(service, "Sockets");
	if(Sockets) {
		xpc_dictionary_apply(Sockets, ^bool(const char* key, xpc_object_t value) {
			const char* SockPathName = xpc_dictionary_get_string(value, "SockPathName");
			if(SockPathName) {
				assert(SockPathName[0] == '/');
				if(patched) SockPathName = rootfs(SockPathName);
				printf("Sockets[%s] SockPathName:%s\n", key, SockPathName);
				xpc_dictionary_set_string(value, "SockPathName", jbroot(SockPathName));
			}
			return true;
		});
	}

	xpc_object_t LaunchEvents = xpc_dictionary_get_dictionary(service, "LaunchEvents");
	if(LaunchEvents) {
		xpc_dictionary_apply(LaunchEvents, ^bool(const char* key, xpc_object_t value) 
		{
			if(strcmp(key, "com.apple.fsevents.matching")==0) 
			{
				xpc_dictionary_apply(value, ^bool(const char* key2, xpc_object_t value2) {
					const char* Path = xpc_dictionary_get_string(value2, "Path");

					assert(Path[0] == '/');
					if(patched) Path = rootfs(Path);
					printf("LaunchEvents[%s][%s] Path:%s\n", key, key2, Path);
					xpc_dictionary_set_string(value2, "Path", jbroot(Path));

					return true;
				});
			}

			else {
				return false;
			}
			
			return true;
		});
	}
	
	xpc_dictionary_set_bool(service, "__Patched", true);
	
	xpc_save_to_file(service, path);
}

void patch_plist(char* path)
{
    struct stat st;
    if(stat(path, &st) < 0)
        return;
    
    if(S_ISDIR(st.st_mode))
    {
        NSURL *dirURL = [NSURL fileURLWithPath:@(jbroot(path)) isDirectory:YES];
        NSArray<NSURL *> *plistURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:dirURL includingPropertiesForKeys:nil options:0 error:nil];
        for (NSURL *plistURL in plistURLs) {
            // contentsOfDirectory always return rootfs-based paths
            patch_plist_file(rootfs(plistURL.path.fileSystemRepresentation));
        }
    } else {
        patch_plist_file(path);
    }
}
