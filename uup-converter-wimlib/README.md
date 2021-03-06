# UUP -> ISO Converter ft. WimLib

* Automated windows command script to process Microsoft Windows 10 **Unified Update Platform** files, allowing to build/convert them into a usable state (ISO / WIM).

* You can get UUP files by performing upgrade from Windows 10 build to later build (starting 15063).

* You can also obtain UUP canonical source using one of these projects:
- [UUP dump website](https://uupdump.ml/)
- [UUP dump downloader](https://gitlab.com/uup-dump/downloader/)
- [UUPDL](https://gitlab.com/uup-dump/uupdl/)
- [UUP Generation Project](https://uup.rg-adguard.net/)
___

## Remarks

* Administrator privileges are required to run the script

* Creating normal boot.wim from UUP require Windows 10 host OS, or installed Windows 10 ADK (Deployment Tools).

otherwise, you will get winre.wim acting as setup boot.wim, without recovery options

- If the upgrade is done via Express UUP (multiple expanded folders in the download directory), you need to perform the UUP > ISO operation before starting the upgrade process (before first restart).

to do so, when WU prompt you to restart, start convert-UUP.cmd and paste the path to download directory, example:

`C:\Windows\SoftwareDistribution\Download\07172dda91861218ecc095600216d792`

Alternatively, if you are testing in VM machine or have multi boot systems, you can choose to Shut down/Restart the system without upgrading.

on Desktop, press Alt+F4 and choose an option without Update.

![example](https://i.imgbox.com/vxZLhGPM.png)
___

## How To Use

- Optional: temporary disable AV or protection program so it doesn't interfere with the process.

- Make sure the files are not read-only or blocked.

- Extract this pack to a folder with simple spaceless path to avoid troubles (example: C:\UUP).

- Place the files in "UUPs" folder to be detected automatically.

Alternatively, you will be prompted to enter other UUP folder path.

- If multiple Editions detected, you will be prompted first to select one of them, or create AIO.

- To exit of the prompt or options menu just press "Enter".

#### Options:

1 - Create ISO with install.wim

4 - Create ISO with install.esd

convert UUP files to a regular ISO distribution that contains install.wim or install.esd file.

2 - Create install.wim

5 - Create install.esd

create install.wim/install.esd file only, which can be used with other ISO with the same version, or for manual apply using dism/wimlib.

3 - UUP Edition info

Display info about detected editions (architecture, language, build version, build branch, editions name).

#### Manual Options

for advanced users, edit convert-UUP.cmd to change the default value

**AutoStart**

If you want to start the conversion process directly without prompts.

This require placing UUP files in *UUPs* folder, or starting convert-UUP.cmd from command prompt with path to UUP source folder

By default this will create ISO with install.wim. For multiple UUP editions it will create AIO ISO with install.wim.

to do so, change `set AutoStart=0` to `set AutoStart=1`

**StartVirtual**

If you want to start create_virtual_editions.cmd directly after conversion is finished

to do so, change `set StartVirtual=0` to `set StartVirtual=1`

**SkipISO**

If you are not interested to create ISO file currently, or intend to create Multi-Architecture ISO (x86/x64) later with multi_arch_iso.cmd, or intend to manually use create_virtual_editions.cmd

to do so, change `set SkipISO=0` to `set SkipISO=1`

**SkipWinRE**

If you are not interested to have recovery environment or want to reduce ISO size/conversion period.. etc, it is possible to skip adding winre.wim to install.wim/install.esd

to do so, change `set SkipWinRE=0` to `set SkipWinRE=1`

p.s. adding winre.wim to install.esd will consume high amount of CPU/RAM

**RefESD**

If you plan to use your local UUP source repeatedly, you can choose to keep converted reference ESD files for future operations instead converting them each time.

to do so, change `set RefESD=0` to `set RefESD=1`

if UUP source is Express, Reference ESDs and Edition ESDs will be copied to new folder *CanonicalUUP*. Practically, this convert/backup Express UUP source to Canonical

if UUP source is Canonical, Reference ESDs will be copied to the same UUP source folder. Original CAB files will be moved to subdirectory *Original*
___

## Add Updates Option

**Info:**

- Starting Windows 10 version 1709, Servicing Stack Update and Latest Cumulative Update are handled and distributed with UUP source. In addition to some small dynamic updates used in upgrades

- According to that, UUP Dump will offer multiple builds for the same Windows 10 version. Each one will represent refreshed Feature Update or new Cumulative Update

- However, those updates are only applied by Windows Update, they not actual part of the UUP source itself and will not be included in the converted ISO/WIM by default

- The recommended choice to get those updates incorporated, is to convert UUP to ISO normally, afterwards you can use W10UI.cmd script or similar projects to integrate the updates

- Nevertheless, **AddUpdates** option provide built-in ability to directly integrate these updates, resulting a refreshed ISO/WIM

**How to:**

- Make sure UUP source contain updates (Windows10.0-KB*.cab files)

- Optional: edit convert-UUP.cmd and change `set AddUpdates=0` to `set AddUpdates=1`

- You must have Windows 10 Host OS, or install Windows 10 ADK

- You must choose an option with install.wim file (option 1 or 2)

- If updates are detected, you will have extra option `9 - Add Updates`. Enter 9 to change the status (Yes or No) before choosing option 1 or 2

**Note:**

by default, superseded components due updates in OS image will be delta-compressed

to rebase OS image and remove superseded components, edit convert-UUP.cmd and change `set ResetBase=0` to `set ResetBase=1` prior conversion

warning: resetbase break "Reset This PC" feature
___

## Virtual Editions

**Info:**

- Starting Windows 10 build 17063, regular editions have been unified into two base editions:

Home & Pro (with their variants Home N & Pro N)

Home China edition is still separate

- According to that, UUP will only deliver installation files for the above editions only

- The following editions are now exist as "virtual upgrade editions" with base editions:

with Home : Home Single Language

with Pro  : Enterprise, Education, Pro Education, Pro for Workstations, Enterprise for Virtual Desktops

with Pro N: Enterprise N, Education N, Pro Education N, Pro N for Workstations

- Therefore, the extra script is to help create these virtual editions from UUP source

**How to:**

- Optional: if you do not intend to keep converted ISO, edit convert-UUP.cmd and `set SkipISO=1`

- Use convert-UUP.cmd to create the converted ISO file/distribution

- Run create_virtual_editions.cmd and choose the desired option from menu

**Options:**

1 - Create all editions

create all possible target virtual editions

2 - Create one edition

create one of the target virtual editions

3 - Create randomly selected editions

create some of the target virtual editions

**Manual Options**

- AutoStart

If you want to start the creation process directly without prompts.  
It will only create editions specified in *AutoEditions* option if possible.

to do so, change `set AutoStart=0` to `set AutoStart=1`

Note: if convert-UUP.cmd is set with AutoStart=1 & StartVirtual=1, create_virtual_editions.cmd will also start with AutoStart=1

- AutoEditions

Specify editions to auto create with *AutoStart* option, separate the editions with a comma ,

Allowed values:  
Enterprise,Education,ProfessionalEducation,ProfessionalWorkstation,EnterpriseN,EducationN,ProfessionalEducationN,ProfessionalWorkstationN,CoreSingleLanguage,ServerRdsh

Example:  
`set AutoEditions=Enterprise,ProfessionalWorkstation,Education`

- DeleteSource

If you do not need to keep the source base editions (example: create Enterprise and delete Pro)

to do so, change `set DeleteSource=0` to `set DeleteSource=1`

- Preserve

To preserve and keep source distribution folder intact, the operation will be done on copied folder instead

to do so, change `set Preserve=0` to `set Preserve=1`

(If source distribution is .ISO file, this option has no affect)

- SkipISO

Do not create final ISO file at the end

to do so, change `set SkipISO=0` to `set SkipISO=1`

___

## Multi-Architecture ISO (x86/x64)

**How to:**

- Optional: if you do not intend to keep single architecture ISOs, edit convert-UUP.cmd and `set SkipISO=1`

- Use convert-UUP.cmd to create two ISO distributions, one for x64 and another for x86. You may select the desired editions to include in each one

- Run multi_arch_iso.cmd and choose the option that suits you

**Options:**

1 - Create ISO with 1 combined install.wim/install.esd

create a custom ISO structure with 1 install.wim/install.esd for all x64/x86 images, and slighlty modified bootx64.wim/bootx86.wim to allow coexistence

2 - Create ISO with 2 separate install.wim/install.esd (Win 10)

create the same ISO structure as Media Creation Tool with 2 separate install.wim/install.esd for each architecture

**Notes:**

- To preserve source single-architecture distributions folders edit multi_arch_iso.cmd and `set Preserve=1`

- If the installation file is install.esd, be aware that option 1 will require high amount of CPU/RAM to unify install.esd files

- multi_arch_iso.cmd can be used also to create multi-architecture ISO from any similar Windows x64/x86 ISO distributions, starting Windows 7 SP1

however, option 2 require Windows 10 setup files
___

## Credits

* [mkuba50](https://gitlab.com/users/mkuba50) - UUP dump
* [Eric Biggers](http://wimlib.net) - wimlib
* [Igor Pavlov](https://www.7-zip.org/) - 7-zip
* [erwan.l](http://reboot.pro/files/file/313-offlinereg) - offlinereg
* [cdob](http://reboot.pro/topic/20471-windows-pe-5x-boot-problem) - create aio efisys.bin
* [@rgadguard](https://twitter.com/rgadguard) - initial script and co-enhancing
* Special thanks to: @Enthousiast, @s1ave77, @Ratiborus58, @NecrosoftCore, @DiamondMonday, @WzorNET
* cdimage and imagex are intellectual property of Microsoft Corporation.
