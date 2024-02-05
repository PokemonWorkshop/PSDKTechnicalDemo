# !!! Before reading this file !!!

To read this file the intended way, open this file using Visual Studio Code (VSCode) and type CTRL+K, then V. It will open the preview of this file.

Enjoy your reading!

# Preface

Hello maker!
If you're reading this, it means you're interested in creating custom scripts for your project!

It may be daunting but fear not, as this document will guide you on your way to the joys of creating custom scripts!

At the time of writing this guide, I'm practically sure I won't dive too deep into this, as knowing how to edit a script
kind of comes with the knowledge of Ruby's inner working (the programming language used by PSDK).

This guide will try to tell you the proper steps you should follow to have the best experience while writing your code, whether
it's editing an existing feature or creating a new one for your project.

# The dev environment

A good developer is a developer with tools, and the right one at that.

You won't see a baker without their furnace, a carpenter without their hammer, etc.

Developers are no different and need specific tools to help them produce the best work
they can offer.

First things first, you should watch this video (in french with english subtitles):
https://www.youtube.com/watch?v=E9zYkR_3rbM

Just in case, here's a quick summary of what you should have installed/done by the end of this video:
- Installed Ruby on your computer (3.0.6 is the current version used by PSDK)
- Installed VSCode (the IDE, basically the code editor)
- Installed the Solargraph gem (autocompleter, linter, and lets you view the doc. of any method you hover over)
- Installed the "Solargraph" extension on VSCode
- Created the symbolic link (let Solargraph parse the PSDK codebase and enable autocompletion)

# The programming language

As I said earlier, PSDK is developed in Ruby. Which means you'll have to know how to use this specific language to write
your custom scripts.

Theoretically, the PSDK codebase is clean and readable enough so that you could learn how to modify the codebase with some
effort.

But, that is something I will not recommend. Ruby is an Object-Oriented Programming (OOP) language, which
means there is a concept of object, classes, inheritance etc.

Basically, there are rules to follow, and those rules can be hard to grasp without a good understanding of some
programming concepts.

This is why I STRONGLY recommend you take some time to learn Ruby first.

I understand it can be frustrating - you want to create a script for your project, not learn a whole language.

Yet, the time you'll allocate now is going to be far less than if you're trying to achieve anything without the proper
knowledge.

Do yourself a favor and LEARN Ruby.

The next links are tutorials I have deemed good enough for an intro to Ruby.

It doesn't mean you have to read/watch them all! Some tutorials may have information that other tutorials lack, and
vice versa, so I do encourage you to view as many as possible!

- [ EN, FR ] Nuri Yuri's (PSDK's creator) written Ruby tutorial: https://gitlab.com/NuriYuri/tutoriel_ruby
- [ EN ] Codecademy's written tutorial: https://www.codecademy.com/learn/learn-ruby
- [ EN ] freeCodeCamp.org's YouTube video: https://www.youtube.com/watch?v=t_ispmWmdjY
- [ FR ] Grafikart's YouTube playlist: https://www.youtube.com/watch?v=vgSQ97FDSvM&list=PLjwdMgw5TTLVVJHvstDYgqTCao-e-BgA8

Your learning should be active if you want to understand Ruby - practice the methods you'll learn, notably by using IRB
(just type irb in the Windows search bar)!

# Creating a custom script

Woohoo, the fun part begins! 🥳

So, now that you have the proper environment, and the proper knowledge of Ruby (I hope?), we can now begin to write
code!

But first, you need to know some useful and kind of mandatory information:
- For Solargraph to work flawlessly, you need to open the scripts folder with VSCode. This way, Solargraph will be able
  to parse the PSDK codebase, while also parsing your own scripts.
- You **CAN'T edit the PSDK codebase**. PSDK was created with an "easily updatable" mindset. Pokémon Studio is
  responsible for updating PSDK, but this comes with a price - scripts can get overwritten between updates, and a Studio
  update will overwrite the whole basecode.
- Custom script files MUST be created in the scripts folder at the root of your project. This means that you can only
  put your custom scripts in the "scripts" folder located at the same place as your "Audio"/"graphics"/"Data" folders.
  Also, don't put your custom script files inside the "psdk_scripts" folder you should have created while watching the
  dev environment setup tutorial - your script won't be read at all.
- Customs scripts are always loaded after the PSDK codebase, and must follow a certain workflow and naming convention
  for PSDK to load them correctly:
  - You can, and should, create folders inside the scripts folder to organize your work. The folders must be named
    following this template: "XXXXX NameOfMyFolder", with XXXXX being any 5 numbers. These numbers help PSDK to know
    the order it should load your custom folders. Example: "00001 MyNewUI"
  - Your custom script files must be named following this template: "XXXXX NameOfMyScript.rb", with XXXXX being any 5
    numbers. These numbers help PSDK to know the order it should load your custom scripts.
    Example: "00001 NewUILogic.rb"
- If you want to modify something from the basecode, make sure to NOT copy the whole file you want to edit, ONLY the
  method you want to edit (and the modules/classes needed for the system to understand what you're doing, of course). If
  you copy the whole file, you're "bastardizing" the whole code with methods from an old version of PSDK. You DON'T want
  to have to fix that, believe me.

You should see an example with the file "00001 NewDynamicLights.rb". I invite you to read it, as it contains some
comments and explains a little how to add lights to the "DynamicLight" feature.

# Knowing what to edit

Alright, now that you know Ruby, you understand the rules about creating a custom script. But still, you don't know where to
begin...

Depending on what you'll want to edit, you'll have to head into different folders.

Most of the time, things are tidily stored in the right subfolder. Here's a list of what you might want to modify, and
where to seek the right files.

The filepaths which will be given will always start from the **symbolic link**.

## "I want to modify the UIs"

To modify the UIs code, you'll need to head to "scripts\01450 Systems".

This folder contains one subfolder per "UI" or important system, and most of the time the UIs are stored here.

Here's an important piece of information: generally, a subfolder of "Systems" will be divided into 3 subfolders:
- The PFM subfolder: this subfolder contains the code files for the "backend" part of the system. Roughly speaking, it
  contains the information which will be stored in the player's save.
- The UI subfolder: this subfolder contains the graphical component of the UI. It might be a button, or a list, or a
  banner, anything that uses images and texts will be found in this subfolder.
- The GamePlay subfolder: this subfolder contains the "brain" of the UI. The code for the logic -the actions played when
  a certain input is pressed...- is stored here.

## "I want to modify methods I call in an event"

RMXP events use what we call the "Interpreter".

It's a class that contains every method accessible by events during their "runtime" which can be called using the
"Insert script command" command of an event.

To modify the methods defined by RMXP, head to "scripts\00600 Script_RMXP", and have a look at the Interpreter_X.rb files.
And, to modify the methods defined by PSDK, head to "scripts\00700 PSDK Event Interpreter".
You'll find lots and lots of useful commands in these two folders.

You can also use the VSCode search function and try to search for "class Interpreter".

## "I want to modify the Battle Engine"

This chapter is kind of a big one.

First, I recommend you read the "PSDK .25 BE.md" file, which explains a LOT of things about the PSDK Battle Engine,
notably how it works.

The folder for the Battle Engine is located at "scripts\01600 Alpha 25 Battle Engine".

### "I want to modify the UI of the Battle Engine"

The code that describes the Battle Engine UI is fragmented into different subfolders:
- "01600 Alpha 25 Battle Engine\00001 Battle_Scene": this subfolder contains the scripts that describe the logic of the
  Battle Engine UI. It also contains the BattleUI subfolder.
  - "01600 Alpha 25 Battle Engine\00001 Battle_Scene\00001 BattleUI": this subfolder contains the graphical components
    used by the Battle Engine UI.
- "01600 Alpha 25 Battle Engine\00002 Battle_Visual": this subfolder contains the scripts that describe the transitions &
  animations used in the UI, like the showing of some windows and graphical elements.
  - "01600 Alpha 25 Battle Engine\00002 Battle_Visual\00001 Animations": this subfolder contains the scripts that
    describe classes involved in some animations.
  - "01600 Alpha 25 Battle Engine\00002 Battle_Visual\00002 Transition": this subfolder contains the scripts that
    describe the Battle transitions that are displayed when the scene switches from the map to the combat.

### "I want to modify the Pokemon in the Battle Engine"

First, a small piece of information: in PSDK, when not in battle, the player contains instances of PFM::Pokemon
in their team.

PFM::Pokemon is a class describing a Pokemon out of battle. When entering a battle, PSDK generates instances of
PFM::PokemonBattler.

The PokemonBattler class is basically a PFM::Pokemon, but with methods specifically thought for battles.

This means that, if you want/need to modify or implement something related to the PokemonBattler class, you'll have to
head to "01600 Alpha 25 Battle Engine\00100 PokemonBattler".

### "I want to modify how Damages are done/Capture works/the battle architecture"

Those mechanics are dependent on the Logic class of the Battle Engine. This class contains :
- "01600 Alpha 25 Battle Engine\00200 Battle_Logic": this subfolder contains files describing several methods and other
  classes that help in handling how a battle works and how it unfolds.
  - "01600 Alpha 25 Battle Engine\00200 Battle_Logic\00000 Battle Info": this subfolder contains the files describing
    the BattleInfo class. This class is used to store all of the battle's preliminary info which are used to generate
    the battle.
  - "01600 Alpha 25 Battle Engine\00200 Battle_Logic\00001 Handlers": this subfolder contains what we call the "Handlers".
    Handlers are classes which are responsible of handling certain mechanics and ensures that they are properly handled from
    start to finish.

### "I want to create a new Move/Ability/Item"

In the PSDK Battle Engine, there is a distinction to make.

Moves are objects of the "Move" class, while Abilities and Items are objects of the "Effects" class.

An Effect can't be a Move, and a Move can't be an Effect.

But, technically, a Move can create and give an Effect to a Pokemon.

You should have a look at some examples in the code to understand this nuance.

- "01600 Alpha 25 Battle Engine\04150 Battle_Move": this subfolder contains the basic definition of the Move class, from
  which every other move will inherit from. It also contains:
  - "01600 Alpha 25 Battle Engine\04150 Battle_Move\00001 Mechanics": this subfolder contains scripts describing
    certain move mechanics which are commonly used by different moves
  - "01600 Alpha 25 Battle Engine\04150 Battle_Move\00010 Definitions": this subfolder contains all the scripts for all
    the currently developed moves inside the Battle Engine. One definition can be used for multiple attacks.
- "01600 Alpha 25 Battle Engine\04000 Effects": this subfolder contains the basic definition of the EffectBase class,
  from which every other Effect will inherit from.
  NOTE: I won't explain which subfolder you'll find there as the name of those subfolders are very self-explanatory.

# A final word

Here you go, maker!

I believe that with this document, you'll be able to do great things in the future.

Of course, if you have any questions, we'll be happy to answer them on our Discord server!

For the last piece of advice from this document - take your time.

Creating a fangame is not a speedrun, it's a marathon.

You need to learn to prioritize your workload or else you'll definitely feel burned out at some point.

As long as you have fun while creating your fangame, and you advance at your own rhythm, everything should go well for
you and your fangame!

Godspeed, maker, we hope to learn from you soon! :D
