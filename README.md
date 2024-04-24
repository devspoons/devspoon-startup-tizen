# devspoon-startup-tizen

devspoon-startup-tizen is an open source solution that can easily build a reliable Tizen development environment using Docker.

## based project

devspoon-startup-tizen is built on top of the open source project [devspoon-startup-web], an integrated management solution catered to startups. It provides nginx-based PHP and Python platforms to develop web and API services. It also enables installing, backing up and managing project solutions critical for startups such as OpenProject, Jenkins, Gitolite (private Git server), and Harbour (private Docker server).

## introduce "Devspoon-Projects"

- We provide an open source infrastructure integration solution that can easily service Python, Django, PHP, etc. using docker-compose. You can install the commercial-level customizable nginx service and redis at once, and install and manage more services at once. If you are interested, please visit [Devspoon-Projects](https://github.com/devspoon/Devspoon-Projects).

## Official guide document

- preparing...

## Project management solutions

- **[OpenProject]** : Open source project management software to help you work on your project efficiently

- **[Jenkins]** : As one of the CI tools, CI (Continuous Integration) refers to continuous integration, which is an automated process for developers, and new code changes are automatically built and tested regularly to notify developers to solve problems that can occur when multiple developers develop simultaneously. Software that helps secure development stability and reliability

- **[Gitolite]** : Configuration Management Tool. user can install git server software at own server

- **[Harbor]** : The Private Docker Registry Server for businesses that store and distribute Docker Images

## Features

- **Support to make configuration files for each service(conf, yml etc)** : Using shell script, you can easily make and manage the configuration files required for nginx, php, dockerfile, etc. with only the information required by the user's keyboard.

- **Efficiently dockerfile configuration for development and service operation** : The log folder is interlocked by "volumes" in docker-compose.yml so that user can can be tracked problems even when the docker container is stopped. Webroot, nginx config, etc. are frequently modified during development so these are interlocked by "volumes"

- **Provide reverse proxy function** : Through a single nginx, you can provide multiple web and app services using PHP and Python, as well as project management services at the same time. Provides a shell script to easily create proxy configuration files for integration with the web UI of other services.

- devspoon-startup-tizen can easily build the complex configuration required to develop Samsung Tizen-based IoT devices using the already verified Dockerfile and Docker-compose.

- Development automation (CI:Continuous Integration) can be configured using jenkins provided as [devspoon-startup-web], and projects can be efficiently managed with openproject.

- Gitolite is linked with openproject and jenkins, and can be used efficiently without repository public and limitations on the capacity restriction of git server and public storage.

- Using the harbor, you can build an independent docker image according to the type, version, and kernel environment type of the smart TV, IoT development board, and download and install the docker image to any new server at any time from the docker hub.

- By configuring devspoon-startup-tizen, when moving to the internal network, you can build a development environment under various conditions and manage sources and projects even when there is no Internet connection.

## Considerations

- **No DB service** : This open source does not provide DB as docker to suggest stable operation. It is recommended to install it on a real server and access it using a network, such as port 3306. We hope that this will be done for distributed services as well. We hope that this will be consider for distributed services as well.

- **Development-oriented docker service** : This open source is perfect for startups or new service development teams that require frequent modifications and testing.

- **This open-source considers generic servers that are not support AWS, GCM** : This open source is intended to be installed and operated on a server that is directly operated, and on general server hosting, and plans to integrate with cloud services such as AWS and GCM in the future

## Install & Run

### How to build web services(PHP, python[gunicorn, uwsgi])

- Refer the guide : [devspoon-web]

### How to build project management solutions(openproject, jenkins, gitolite[private git server], harbor[private docker server])

- Refer the guide : [devspoon-startup-web]
- I have sample code on junkins_home. If you want the reset environment, delete all the contents.
- Sample Jenkins account info **ID: admin PASSWORD: 1324**

### How to build Tizen development environment

- Build GBS(Tizen Build Server) by user self : https://source.tizen.org/documentation/developer-guide/all-one-instructions/creating-tizen-images-scratch-one-page
- Interlock GBS(Tizen Build Server) with jenkins(CI) by user self : https://source.tizen.org/documentation/developer-guide/all-one-instructions/one-click-solution-tizen-image-creation-based-on-jenkins-framework

1. Prepare ssh key

   - Register a user account at [tizen web-site].
   - A user have to make ssh key to using ssh-keygen to register on tizen development official website for accessing tizen repository.
   - Log in to Tizen Gerrit(https://review.tizen.org/gerrit) and upload the key
     - In the Gerrit(https://review.tizen.org/gerrit) Web page, get login and go click settings and add your id_rsa.pub at the menu of "SSH Public Keys".
   - A user have to copy made ssh keys to docker/tizen-env/.ssh.
   - If A user want to access tizen container directly for development, can add new location of "volumes" in a docker-compose.yml.
   - If A user want to access tizen container by ssh for development, make a new ssh key and add your pub key to an end of authorized_keys at docker/tizen-env/.ssh. if there are no authorized_keys, A user have to make this file.

2. Update Tizen ssh config file

   - docker/tizen-env/.ssh/config

   ```shell
   Host tizen review.tizen.org
   Hostname review.tizen.org
   IdentityFile ~/.ssh/id_rsa
   User Tizen_Account_ID #update this user information what already registered ID from Tizen official website!!!
   Port 29418
   # Add the line below when using proxy, otherwise, skip it.
   # ProxyCommand nc -X5 -x <Proxy Address>:<Port> %h %p
   ```

3. Configuring Git for Gerrit Access

   - Update git information at docker/tizen-env/Dockerfile

   ```shell
   docker/tizen-env/Dockerfile

   git config --global user.name "ID" #fill ID
   git config --global user.email "E-MAIL" #fill E-MAIL
   ```

4. Run docker-compose.yml

   - How to build only Tizen Environment

   ```sh
   $ cd compose/dev_env_service/tizen-env
   $ docker-compose up -d
   ```

   - How to build full service (require setting [devspoon-web], [devspoon-startup-web])

   ```sh
   $ cd compose/master_service
   $ docker-compose up -d
   ```

5. A user selection

   - If user want to download some package or use existing project, doesn't need this step. this job require huge local size over the hundreds GB
   - It try to get all tizen repository package in a user's local
   - A user can run "repo init" using shell script at /root/repo-script there are two kind of shell script files for all case or raspberry pi 3
     - This step will require the local repository size over the hundreds GB

6. Test sample project

   - There are two number of projects for anchor5 and raspberry pi 3 at /root/samples
   - It try to build with "peripheral-io" package assume user updated this package's code
     - The result will be "tizen-unified_iot-headed-3parts-armv7l-artik530.tar.gz" at /Tizen-Work/mic-output

## Additional development item

- System integration between jenkins, gitolite, tizen-env.
- Development tizen image management solution.
  - The tizen image management solution UI sample design
    ![Tizen image mng server]

## Community

- **Personal Website** : Owner's personal website is [devspoon.com](devspoon.com)

## Partners and Users

- Lim Do-Hyun Owner Developer/project Manager, bluebamus@gmail.com
  Personal site : [devspoon.com](devspoon.com)

- Lim Tae-youn Member, Tizen Designer
- Kang Dong-hoon Member, Tizen Developer

### How to contributing our project

- devspoon-startup-tizen code is hosted and maintained using [GitHub](https://github.com/ainpeople/devspoon-startup-tizen).
  We plan to contribute to third-party tools in the Tizen official repository(https://review.tizen.org/git/).
- To contribute to devspoon-startup-tizen, please refer to [GitHub](https://github.com/ainpeople/devspoon-startup-tizen). It
  should includes most of the things you'll need to get your contribution started!

<!-- Markdown link & img dfn's -->

[Tizen ssh key 등록 저장소]: https://review.tizen.org/gerrit
[ssh-config]: https://github.com/ainpeople/ainpeople_doc/raw/master/ainci-tizen/images/ssh_config.png
[tizen-register-site]: https://github.com/ainpeople/ainpeople_doc/blob/master/devspoon-startup-tizen/images/tizen_ssh_register.png
[ssh-config]: https://github.com/ainpeople/ainpeople_doc/blob/master/devspoon-startup-tizen/images/ssh_config.png
[ssh-success-msg]: https://github.com/ainpeople/ainpeople_doc/raw/master/ainci-tizen/images/ssh_result.png
[Tizen 수동 환경 설치 & 추가 정보 제공]: https://github.com/ainpeople/ainpeople_doc
[Tizen 수동 환경 설치]: https://source.tizen.org/ko/documentation/developer-guide/getting-started-guide
[Tizen image mng server]: https://github.com/ainpeople/ainpeople_doc/raw/master/ainci-tizen/images/sample_tizen.PNG
[devspoon-startup-tizen Build]: https://github.com/ainpeople/ainpeople_doc/raw/master/ainci-tizen/images/AinCI-Tizen_build.jpg
[Tizen jenkins 기반 설치 공식 메뉴얼]: https://source.tizen.org/ko/documentation/developer-guide/all-one-instructions/one-click-solution-tizen-image-creation-based-on-jenkins-framework
[Tizen documentation]: https://source.tizen.org/documentation
[Tizen 공식 사이트]: https://www.tizen.org/ko?langswitch=ko
[docker-install]: https://hcnam.tistory.com/25
[devspoon-web]: https://github.com/devspoons/devspoon-web
[devspoon-startup-web]: https://github.com/devspoons/devspoon-startup-web
[OpenProject(KR)]: http://wiki.webnori.com/display/pms/Open+Project+7
[Jenkins(KR)]: https://jjeongil.tistory.com/810
[Harbor(KR)]: https://engineering.linecorp.com/ko/blog/harbor-for-private-docker-registry/
[mailgun]: https://www.mailgun.com/
[sendgrid]: https://sendgrid.com/
[OpenProject]: https://docs.openproject.org/user-guide/wiki/
[Jenkins]: https://en.wikipedia.org/wiki/Jenkins_(software)
[Gitolite]: https://wiki.archlinux.org/index.php/Gitolite
[Harbor]: https://en.wikipedia.org/wiki/Harbor
[Tizen-Builder-Env]: https://source.tizen.org/
[tizen web-site]: https://www.tizen.org/user/register
[bluebamus.github.io]: bluebamus.github.io
[devspoons.github.io]: devspoons.github.io
