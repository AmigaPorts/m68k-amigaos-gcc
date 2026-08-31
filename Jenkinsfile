def notify(status){
	emailext (
		body: '$DEFAULT_CONTENT',
		recipientProviders: [
			[$class: 'CulpritsRecipientProvider'],
			[$class: 'DevelopersRecipientProvider'],
			[$class: 'RequesterRecipientProvider']
		],
		replyTo: '$DEFAULT_REPLYTO',
		subject: '$DEFAULT_SUBJECT',
		to: '$DEFAULT_RECIPIENTS'
	)
}

@NonCPS
def jobLabels(jobName) {
	def parts = jobName.split(/\/{1}/)
	return [
		group: parts[0],
		name: (parts.length > 1 ? parts[1] : parts[0]).replace('%2F', ' ')
	]
}

def notifyFailure(labels, target) {
	currentBuild.result = 'FAILURE'
	discordSend description: "Build Failed: ${labels.name} #${env.BUILD_NUMBER} Target: ${target}", customUsername: "AmigaDev", customAvatarUrl: "https://avatars.githubusercontent.com/u/34406884?s=400&u=770fb7263ff469e25bb120eb2c0e44a16beda385&v=4", footer: "AmigaDev CI/CD", link: env.BUILD_URL, result: 'FAILURE', title: "[${labels.group}] Build Failed: ${labels.name} #${env.BUILD_NUMBER}", webhookURL: env.AMIGADEV_WEBHOOK
	notify("Build Failed: ${labels.name} #${env.BUILD_NUMBER} Target: ${target}")
}

@NonCPS
def shouldPublish(branchName, isPullRequest) {
	return !isPullRequest && ['master', 'gcc10', 'dev'].contains(branchName)
}

@NonCPS
def killall_jobs() {
	def jobname = env.JOB_NAME
	def buildnum = env.BUILD_NUMBER.toInteger()
	def killnums = ""
	def job = Jenkins.instance.getItemByFullName(jobname)
	def fixed_job_name = env.JOB_NAME.replace('%2F','/')

	for (build in job.builds) {
		if (!build.isBuilding()) { continue; }
		if (buildnum == build.getNumber().toInteger()) { continue; println "equals" }
		if (buildnum < build.getNumber().toInteger()) { continue; println "newer" }

		echo "Kill task = ${build}"

		killnums += "#" + build.getNumber().toInteger() + ", "

		build.doStop();
	}

	if (killnums != "") {
		//slackSend color: "danger", channel: "#jenkins", message: "Killing task(s) ${fixed_job_name} ${killnums} in favor of #${buildnum}, ignore following failed builds for ${killnums}"
	}
	echo "Done killing"
}

def buildStep(buildConf, DOCKER_ROOT, DOCKERIMAGE, DOCKERTAG, DOCKERFILE, BUILD_NEXT, BUILD_PARAM) {
	def labels = jobLabels(env.JOB_NAME)
	def buildenv = '';
	def tag = '';
	def isPullRequest = env.CHANGE_ID?.trim();
	def branchName = isPullRequest ? env.CHANGE_TARGET : env.BRANCH_NAME;
	def publish = shouldPublish(branchName, isPullRequest);

	try {
		checkout scm;

		if (branchName == 'master') {
			buildenv = 'production';
			tag = "${DOCKERTAG}";
		} else if (branchName == 'gcc10') {
			buildenv = 'production';
			tag = "${DOCKERTAG}";
			if (!isPullRequest) {
				env.BRANCH_NAME = "master";
			}
		} else if (branchName == 'dev') {
			buildenv = 'development';
			tag = "${DOCKERTAG}-dev";
		} else {
			buildenv = 'production';
			tag = "${DOCKERTAG}";
		}

		def buildArgs = "--build-arg BUILDENV=${buildenv} --build-arg PATHPREFIX=${buildConf.PathPrefix} --build-arg GCC_BRANCH=${buildConf.GCCBranch} --build-arg BINUTILS_BRANCH=${buildConf.BinutilsBranch} --network=host --pull -f ${DOCKERFILE} .";
		docker.withRegistry("https://index.docker.io/v1/", "dockerhub") {
			def customImage
			stage("Building ${DOCKERIMAGE}:${tag}...") {
				customImage = docker.build("${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}", buildArgs);
			}

			if (!publish) {
				stage("Skipping publication of ${DOCKERIMAGE}:${tag}") {
					echo "Unpublished branch or PR build completed; no image will be pushed.";
				}
			} else {
				stage("Pushing to docker hub registry...") {
					customImage.push();
				}
			}
		}

	} catch(err) {
		notifyFailure(labels, "${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}")
		throw err
	}
}

def buildManifest(DOCKER_ROOT, DOCKERIMAGE, DOCKERTAG, DOCKERFILE, PLATFORMS, BUILD_NEXT, BUILD_PARAM) {
	def labels = jobLabels(env.JOB_NAME)
	def buildenv = ''
	def tag = ''
	def isPullRequest = env.CHANGE_ID?.trim()
	def branchName = isPullRequest ? env.CHANGE_TARGET : env.BRANCH_NAME
	def publish = shouldPublish(branchName, isPullRequest)
	try {
		if (!publish) {
			stage("Skipping ${DOCKERIMAGE}:${DOCKERTAG} manifest publication") {
				echo "Unpublished branch or PR platform builds completed; no manifest will be created and no downstream builds will be triggered.";
			}
			return;
		}

		checkout scm;

		if (branchName == 'master' || branchName == 'gcc10') {
			buildenv = 'production';
			tag = "${DOCKERTAG}";
		} else if (branchName == 'dev') {
			buildenv = 'development';
			tag = "${DOCKERTAG}-dev";
		}

		docker.withRegistry("https://index.docker.io/v1/", "dockerhub") {
			stage("Building ${DOCKERIMAGE}:${tag} manifest...") {
				sh('docker version');
				def platformsString = "";
				PLATFORMS.each { p ->
					sh("docker pull ${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}_${p}");
					platformsString = "${platformsString} ${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}_${p}"
				}
				
				sh("docker manifest create ${DOCKER_ROOT}/${DOCKERIMAGE}:${tag} ${platformsString}");
				sh("docker manifest push ${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}");
			}
		}
		def branches = [:]

		BUILD_NEXT.each { v ->
			branches["Build ${v}"] = { 
				build(job: "${v}/${env.BRANCH_NAME}", wait: true, parameters: [string(name: 'BUILD_IMAGE', value: String.valueOf(BUILD_PARAM))]);
			}
		}

		parallel branches;
	} catch(err) {
		notifyFailure(labels, "${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}")
		throw err
	}
}

node('master') {
	killall_jobs();
	def labels = jobLabels(env.JOB_NAME)
	
	checkout scm;
	
	env.COMMIT_MSG = sh (
		script: 'git log -1 --pretty=%B ${GIT_COMMIT}',
		returnStdout: true
	).trim();

	discordSend description: "${env.COMMIT_MSG}", customUsername: "AmigaDev", customAvatarUrl: "https://avatars.githubusercontent.com/u/34406884?s=400&u=770fb7263ff469e25bb120eb2c0e44a16beda385&v=4", footer: "AmigaDev CI/CD", link: env.BUILD_URL, result: currentBuild.currentResult, title: "[${labels.group}] Build Started: ${labels.name} #${env.BUILD_NUMBER}", webhookURL: env.AMIGADEV_WEBHOOK;

	def branches = [:]
	def project = readJSON file: "JenkinsEnv.json";

	project.builds.each { v ->
		branches["Build ${v.DockerRoot}/${v.DockerImage}:${v.DockerTag}"] = {
			def platforms = [:];

			v.Platforms.each { p -> 
				platforms["Build ${v.DockerRoot}/${v.DockerImage}:${v.DockerTag}_${p}"] = {
					stage("Build ${p} version") {
						node(p) {
							buildStep(v, v.DockerRoot, v.DockerImage, "${v.DockerTag}_${p}", v.Dockerfile, [], v.BuildParam);
						}
					}
				}
			};

			parallel platforms;

			stage('Build multi-arch manifest') {
				node() {
					buildManifest(v.DockerRoot, v.DockerImage, v.DockerTag, v.Dockerfile, v.Platforms, v.BuildIfSuccessful, v.BuildParam);
				}
			}
		}
	}
	
	sh "rm -rf ./*"

	parallel branches;
}
