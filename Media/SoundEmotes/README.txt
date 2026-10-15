Sound emotes
============

Drop your sound emote audio files in this folder. mp3 is preferred; ogg also
works. wav is not supported by the game, and the files must be here before you
start (or restart) World of Warcraft.

A few short placeholder sounds are included so you can try the feature right
away: ding, boing, pop, boom and oof. Replace them with your own files (same
name) or delete them.

Type a sound emote in TrialChat with two slashes, for example:

    //laugh
    //cheer
    //vineboom

The file is looked up by the command name with an .mp3 extension, so //laugh
plays "laugh.mp3" from this folder. If you use a different file name or
extension, add it to TrialChatSoundEmotes.lua (in the addon folder), which maps
each sound emote name to its file:

    laugh = "laugh.mp3",

If the sound emote is also a normal emote, sending it plays the sound and also
sends the normal emote to chat. If it is only a sound emote, just the sound
plays for you. Missing files simply do not play.

Loudness
--------

The game gives addons no way to set a sound's volume, so sound emotes are made
louder by playing the file on several sound channels at the same time; the game
mixes them together, which is louder than one channel. The channels used are
listed in TrialChatCommon.lua:

    TrialChatCommon.SoundEmoteChannels = { "Master", "SFX", "Dialog" }

Add "Ambience" or "Music" for even more, or remove entries to make it quieter.
Each extra channel is louder, but can also clip (distort) a file that is
already loud. This never modifies your audio files, and it respects whatever
volume you have set for each channel.
