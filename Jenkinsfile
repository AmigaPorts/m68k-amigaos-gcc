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

def buildStep(DOCKER_ROOT, DOCKERIMAGE, DOCKERTAG, DOCKERFILE, BUILD_NEXT, BUILD_PARAM) {
	def split_job_name = env.JOB_NAME.split(/\/{1}/);
	def fixed_job_name = split_job_name[1].replace('%2F',' ');
	def buildenv = '';
	def tag = '';

	try {
		checkout scm;


		if (env.BRANCH_NAME.equals('master')) {
			buildenv = 'production';
			tag = "${DOCKERTAG}";
		} else if (env.BRANCH_NAME.equals('gcc10')) {
			buildenv = 'production';
			tag = "${DOCKERTAG}";
			env.BRANCH_NAME = "master";
		} else if (env.BRANCH_NAME.equals('dev')) {
			buildenv = 'development';
			tag = "${DOCKERTAG}-dev";
		} else {
			throw new Exception("Invalid branch, stopping build!");
		}

		docker.withRegistry("https://index.docker.io/v1/", "dockerhub") {
			def customImage
			stage("Building ${DOCKERIMAGE}:${tag}...") {
				customImage = docker.build("${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}", "--build-arg BUILDENV=${buildenv} --network=host --pull -f ${DOCKERFILE} .");
			}

			stage("Pushing to docker hub registry...") {
				customImage.push();
			}
		}

	} catch(err) {
		discordSend description: "Build Failed: ${fixed_job_name} #${env.BUILD_NUMBER} Target: ${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}", customUsername: "AmigaDev", customAvatarUrl: "https://avatars.githubusercontent.com/u/34406884?s=400&u=770fb7263ff469e25bb120eb2c0e44a16beda385&v=4", footer: "AmigaDev CI/CD", link: env.BUILD_URL, result: currentBuild.currentResult, title: "[${split_job_name[0]}] Build Failed: ${fixed_job_name} #${env.BUILD_NUMBER}", webhookURL: env.AMIGADEV_WEBHOOK
		currentBuild.result = 'FAILURE'
		notify("Build Failed: ${fixed_job_name} #${env.BUILD_NUMBER} Target: ${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}")
		throw err
	}
}

def buildManifest(DOCKER_ROOT, DOCKERIMAGE, DOCKERTAG, DOCKERFILE, PLATFORMS, BUILD_NEXT, BUILD_PARAM) {
	def fixed_job_name = env.JOB_NAME.replace('%2F','/')
	try {
		checkout scm;

		def buildenv = '';
		def tag = '';
		if (env.BRANCH_NAME.equals('master')) {
			buildenv = 'production';
			tag = "${DOCKERTAG}";
		} else if (env.BRANCH_NAME.equals('dev')) {
			buildenv = 'development';
			tag = "${DOCKERTAG}-dev";
		} else {
			throw new Exception("Invalid branch, stopping build!");
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
		discordSend description: "Build successful: ${fixed_job_name} #${env.BUILD_NUMBER} Target: ${DOCKER_ROOT}/${DOCKERIMAGE}:${tag} successful!", customUsername: "AmigaDev", customAvatarUrl: "https://avatars.githubusercontent.com/u/34406884?s=400&u=770fb7263ff469e25bb120eb2c0e44a16beda385&v=4", footer: "AmigaDev CI/CD", link: env.BUILD_URL, result: currentBuild.currentResult, title: "[${split_job_name[0]}] Build Successful: ${fixed_job_name} #${env.BUILD_NUMBER}", webhookURL: env.AMIGADEV_WEBHOOK
		def branches = [:]

		BUILD_NEXT.each { v ->
			branches["Build ${v}"] = { 
				build(job: "${v}/${env.BRANCH_NAME}", wait: true, parameters: [string(name: 'BUILD_IMAGE', value: String.valueOf(BUILD_PARAM))]);
			}
		}

		parallel branches;
	} catch(err) {
		discordSend description: "Build Failed: ${fixed_job_name} #${env.BUILD_NUMBER} Target: ${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}", customUsername: "AmigaDev", customAvatarUrl: "https://avatars.githubusercontent.com/u/34406884?s=400&u=770fb7263ff469e25bb120eb2c0e44a16beda385&v=4", footer: "AmigaDev CI/CD", link: env.BUILD_URL, result: currentBuild.currentResult, title: "[${split_job_name[0]}] Build Failed: ${fixed_job_name} #${env.BUILD_NUMBER}", webhookURL: env.AMIGADEV_WEBHOOK

		currentBuild.result = 'FAILURE'
		notify("Build Failed: ${fixed_job_name} #${env.BUILD_NUMBER} Target: ${DOCKER_ROOT}/${DOCKERIMAGE}:${tag}")
		throw err
	}
}

node('master') {
	killall_jobs();
	def split_job_name = env.JOB_NAME.split(/\/{1}/);
	def fixed_job_name = split_job_name[1].replace('%2F',' ');
	
	checkout scm;
	
	env.COMMIT_MSG = sh (
		script: 'git log -1 --pretty=%B ${GIT_COMMIT}',
		returnStdout: true
	).trim();

	discordSend description: "${env.COMMIT_MSG}", customUsername: "AmigaDev", customAvatarUrl: "https://avatars.githubusercontent.com/u/34406884?s=400&u=770fb7263ff469e25bb120eb2c0e44a16beda385&v=4", footer: "AmigaDev CI/CD", link: env.BUILD_URL, result: currentBuild.currentResult, title: "[${split_job_name[0]}] Build Started: ${fixed_job_name} #${env.BUILD_NUMBER}", webhookURL: env.AMIGADEV_WEBHOOK;

	def branches = [:]
	def project = readJSON file: "JenkinsEnv.json";

	project.builds.each { v ->
		branches["Build ${v.DockerRoot}/${v.DockerImage}:${v.DockerTag}"] = {
			def platforms = [:];

			v.Platforms.each { p -> 
				platforms["Build ${v.DockerRoot}/${v.DockerImage}:${v.DockerTag}_${p}"] = {
					stage("Build ${p} version") {
						node(p) {
							buildStep(v.DockerRoot, v.DockerImage, "${v.DockerTag}_${p}", v.Dockerfile, [], v.BuildParam);
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
