# imgur-grab

More information about the archiving project can be found on the ArchiveTeam wiki: [Imgur](https://wiki.archiveteam.org/index.php?title=Imgur)

## Setup instructions

### General instructions

Data integrity is very important in Archive Team projects. Please note the following important rules:

* [Do not use proxies or VPNs](https://wiki.archiveteam.org/index.php/ArchiveTeam_Warrior#Can_I_use_whatever_internet_access_for_the_Warrior?).
* Run the project using the either the Warrior or the project-specific Docker container as listed below. [Do not modify project code](https://wiki.archiveteam.org/index.php/ArchiveTeam_Warrior#I'd_like_to_help_write_code_or_I_want_to_tweak_the_scripts_to_run_to_my_liking._Where_can_I_find_more_info?_Where_is_the_source_code_and_repository?). Compiling the project dependencies yourself is no longer supported.
* You can share your tracker nickname(s) across machine(s) you personally operate, but not with machines operated by other users. Nickname sharing makes it harder to inspect data if a problem arises.
* [Use clean internet connections](https://wiki.archiveteam.org/index.php/ArchiveTeam_Warrior#Can_I_use_whatever_internet_access_for_the_Warrior?).
* Only x64-based machines are supported. [ARM (used on Raspberry Pi and Apple Silicon Macs) is not currently supported](https://wiki.archiveteam.org/index.php/ArchiveTeam_Warrior#Can_I_run_the_Warrior_on_ARM_or_some_other_unusual_architecture?).
* See the [Archive Team Wiki](https://wiki.archiveteam.org/index.php/ArchiveTeam_Warrior#Warrior_FAQ) for additional information.

We strongly encourage you to join the IRC channel associated with this project in order to be informed about project updates and other important announcements, as well as to be reachable in the event of an issue. The Archive Team Wiki has [more information about IRC](https://wiki.archiveteam.org/index.php/Archiveteam:IRC). We can be found at hackint IRC [#imgone](https://webirc.hackint.org/#irc://irc.hackint.org/#imgone).

**If you have any questions or issues during setup, please review the wiki pages or contact us on IRC for troubleshooting information.**

### Running the project

#### Archive Team Warrior (recommended for most users)

This and other archiving projects can easily be run using the [Archive Team Warrior](https://wiki.archiveteam.org/index.php/ArchiveTeam_Warrior) virtual machine. Follow the [instructions on the Archive Team wiki](https://wiki.archiveteam.org/index.php/ArchiveTeam_Warrior) for installing the Warrior, and from the web interface running at `http://localhost:8001/`, enter the nickname that you want to be shown as on the tracker. There is no registration, just pick a nickname you like. Then, select the `Imgur` project in the Warrior interface.

#### Project-specific Docker container (for more advanced users)

Alternatively, more advanced users can also run projects using Docker. While users of the Warrior can switch between projects using a web interface, Docker containers are specific to each project. However, while the Warrior supports a maximum of 6 concurrent items, a Docker container supports a maximum of 20 concurrent items. The instructions below are a short overview. For more information and detailed explanations of the commands, follow the follow the [Docker instructions on the Archive Team wiki](https://wiki.archiveteam.org/index.php/Running_Archive_Team_Projects_with_Docker).

It is advised to use [Watchtower](https://github.com/containrrr/watchtower) to automatically update the project container:

    docker run -d --name watchtower --restart=unless-stopped -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --label-enable --cleanup --interval 3600

after which the project container can be run:

    docker run -d --name archiveteam --label=com.centurylinklabs.watchtower.enable=true --restart=unless-stopped atdr.meo.ws/archiveteam/imgur-grab --concurrent 1 YOURNICKHERE

Be sure to replace `YOURNICKHERE` with the nickname that you want to be shown as on the tracker. There is no registration, just pick a nickname you like.

### Supporting Archive Team

Behind the scenes Archive Team has infrastructure to run the projects and process the data with. If you would like to help out with the costs of our infrastructure, a donation on our [Open Collective](https://opencollective.com/archiveteam) would be very welcome.

### Issues in the code

If you notice a bug and want to file a bug report, please use the GitHub issues tracker.

Are you a developer? Help write code for us! Look at our [developer documentation](https://wiki.archiveteam.org/index.php?title=Dev) for details.

### Other problems

Have an issue not listed here? Join us on IRC and ask! We can be found at hackint IRC [#imgone](https://webirc.hackint.org/#irc://irc.hackint.org/#imgone).


