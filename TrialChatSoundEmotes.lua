-- Sound emotes.
--
-- A sound emote is just like a normal emote, but it also plays a local audio
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
-- If the sound emote is also a normal emote (it appears in
-- TrialChatCommon.EmoteDescriptions), sending it plays the sound *and* sends
-- the usual emote to chat, so everyone else sees it. If it is only a sound
-- emote, just the sound plays for you.

TrialChatCommon.SoundEmotes = {
    -- Normal emotes with a fitting sound.
    magnets = "magnets.mp3",
    fart = "fart.mp3",
    error = "error.mp3",
    impostor = "impostor.mp3",
    dejavu = "dejavu.mp3",
    dubist = "dubist.mp3",
    rip = "rip.mp3",
    fine = "fine.mp3",
    huh = "huh.mp3",
    omg = "omg.mp3",
    punch = "punch.mp3",
    putin = "putin.mp3",
    run = "run.mp3",
    danger = "danger.mp3",
}
