-- input/phrases.lua
--
-- Words and phrases to make pictures of, and what each one means.
--
-- For a general: the two archives this project reads gloss single characters.
-- They say nothing about words -- so a word's meaning has to be written down by
-- somebody, and this is where. A course's vocabulary list goes here. One word
-- typed on a command line is a demonstration; a list of the four hundred a
-- chapter covers is a study set.
--
--   luajit src/031-make-them-all.lua --phrases
--
-- The key is the word as it is written. The value is its meanings, commonest
-- first, the way the character archive orders a character's.

return {
  ["日本"]     = { "Japan" },
  ["日本語"]   = { "the Japanese language" },
  ["時間"]     = { "time", "an hour" },
  ["山口"]     = { "a mountain pass", "the mouth of a valley" },
  ["人口"]     = { "population" },
  ["木曜日"]   = { "Thursday" },
  ["大学"]     = { "a university" },
  ["先生"]     = { "a teacher" },
  ["電話"]     = { "a telephone" },
  ["電車"]     = { "an electric train" },
  ["火山"]     = { "a volcano" },
  ["水中"]     = { "underwater" },
}
