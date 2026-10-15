-- Sound emotes.
--
-- A sound emote is just like a normal emote, but it also plays an audio
-- file. Trigger it with "//" instead of "/", for example:
--
--     //laugh
--     //cheer
--
-- Each entry maps the sound emote's name to the audio file that lives in
-- Media/SoundEmotes. Keeping it in the same format as TrialChatEmotes.lua:
-- the key is the name you type and the value is the file to play.
--
-- The value is the file name inside the Media/SoundEmotes folder, including
-- its extension. mp3 is preferred, ogg also works (wav is not supported by
-- the game). For instance, this:
--
--     laugh = "laugh.mp3",
--
-- plays Interface\AddOns\TrialChat\Media\SoundEmotes\laugh.mp3 for //laugh.
--
-- Names that aren't listed here still work: they fall back to "<name>.mp3",
-- so if you only want to drop a file in the folder you can, without touching
-- this file. Add an entry when the file name is something other than the
-- command (or you want to use a different extension), or to keep the list of
-- available sound emotes in one place. Missing files simply don't play.
--
-- Sending a sound emote also sends its name to the TrialChat players around
-- you (and to everyone in your TrialChat group). Only the name travels: each
-- of them plays their own copy of the same file, so they hear it too, and a
-- name they have no file for simply doesn't play for them.
--
-- If the sound emote is also a normal emote (it appears in
-- TrialChatCommon.EmoteDescriptions), sending it plays the sound *and* sends
-- the usual emote to chat, so everyone else sees it and hears it. If it is
-- only a sound emote, it is heard but doesn't show as a chat line.

TrialChatCommon.SoundEmotes = {
    -- Normal emotes with a fitting sound.
    error = "error.mp3",
    huh = "huh.mp3",
    magnets = "magnets.mp3",
    danger = "danger.mp3",
    fart = "fart.mp3",
    heehee = "heehee.mp3",
    impostor = "impostor.mp3",
    dejavu = "dejavu.mp3",
    dubist = "dubist.mp3",
    rip = "rip.mp3",
    fine = "fine.mp3",
    omg = "omg.mp3",
    punch = "punch.mp3",
    putin = "putin.mp3",
    run = "run.mp3",
    yrunning = "yrunning.mp3",
    goodboy = "goodboy.mp3",
    bonecrack = "bonecrack.mp3",
    pinkman = "pinkman.mp3",
    pickle = "pickle.mp3",
    meow = "meow.mp3",
}

-- How long each file plays, in seconds, measured from the files themselves.
-- Sound emotes never play over each other, so TrialChatCommon uses this to
-- know when the sound that is playing has finished and the next one can start
-- (see TrialChatCommon.SoundEmoteDefaultDuration for files missing here). The
-- key is the file name, so entries keep working if a name is remapped above.
-- Update an entry when you replace a file with one of a different length; a
-- file with no entry just uses the default, which may cut it short or let the
-- next sound start over it if the file is much longer.
TrialChatCommon.SoundEmoteDurations = {
    ["bonecrack.mp3"] = 1.10,
    ["danger.mp3"] = 1.62,
    ["dejavu.mp3"] = 6.27,
    ["dubist.mp3"] = 7.34,
    ["error.mp3"] = 1.02,
    ["fart.mp3"] = 0.37,
    ["fine.mp3"] = 6.11,
    ["goodboy.mp3"] = 1.72,
    ["heehee.mp3"] = 1.46,
    ["huh.mp3"] = 0.67,
    ["impostor.mp3"] = 4.62,
    ["magnets.mp3"] = 4.05,
    ["omg.mp3"] = 1.67,
    ["pinkman.mp3"] = 8.33,
    ["punch.mp3"] = 1.57,
    ["putin.mp3"] = 7.39,
    ["rip.mp3"] = 10.22,
    ["run.mp3"] = 8.28,
    ["yrunning.mp3"] = 1.65,
    ["meow.mp3"] = 0.85,
}
