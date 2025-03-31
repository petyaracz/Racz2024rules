# take rules and features and celex from original MGL fit and make tidy rules for our intput-output pairs

# -- head -- #

setwd('~/Github/Racz2024rules/')

library(tidyverse)
library(glue)
library(magrittr)

# -- fun -- #

# combine rule with features, get feature description
getFeatures = function(df1){
  df1 %<>% 
    left_join(features, by = join_by(segment)) |> 
    select_if(~all(. == .[1])) |> 
    distinct() |>
    select(
      where(
        ~!all(is.na(.x))
      )
    )
  df1 = paste(paste(df1[1, ], names(df1), sep = " "), collapse = ", ")
  df1 = glue('[{df1}]')
  return(df1)
}

# -- read -- #

r = read_tsv('https://raw.githubusercontent.com/petyaracz/RaczBecknerHayPierrehumbert2019/refs/heads/master/models/mgl/baseline_mgl/CELEXFull3.sum')
celex = read_tsv('https://raw.githubusercontent.com/petyaracz/RaczBecknerHayPierrehumbert2019/refs/heads/master/models/mgl/baseline_mgl/CELEXFull3in.tsv'), col_names = F)
f = read_tsv('https://raw.githubusercontent.com/petyaracz/RaczBecknerHayPierrehumbert2019/refs/heads/master/models/mgl/baseline_mgl/CELEXFull3.fea')

# -- main -- #

# tidy up features
features = f |> 
  select(-ASCII) |> # remove ascii col
  rename(segment = `Seg.`) |>  # change name of segment col
  slice(-1) |>  # drop first row
  mutate_all(~ifelse(. == -1, NA, .)) # -1 means underspecified. we change it to NA

# tidy up rules. remove stress, glue together rule
rules = r |> 
  mutate(
    present = str_replace(form1, '»', ''),
    past = str_replace(form2, '»', ''),
    rule = case_when(
      is.na(Qfeat) & !is.na(Q) ~ glue('{A} -> {B} \ {Pfeat}{P} _ {Q}'),
      !is.na(Qfeat) & is.na(Q) ~ glue('{A} -> {B} \ {Pfeat}{P} _ {Qfeat}'),
      is.na(Qfeat) & is.na(Q) ~ glue('{A} -> {B} \ {Pfeat}{P} _ ')
    ) |> 
      str_replace_all('NA', '')
  ) |> 
  select(rule,past,present,A,B,Change,P,Pfeat,Q,Qfeat,scope,hits,reliability,confidence,`related forms`,exceptions)

# add rule id
rules = rules |> 
  distinct(rule,scope,hits) |> 
  mutate(rule_id = glue('rule {1:n()}')) |> 
  left_join(rules)

# nice rules: we want to have related forms and exceptions NOT in disc but in orthography. so we get those.
celex2 = celex |> 
  rename(ahpa = X1, orth = X4) |> 
  distinct(ahpa, orth)

# duplicates because of orthography: raise raze and so on.
# we get rows of related forms and exceptions for rules...
rules_forms = rules |> 
  distinct(rule,rule_id,Change,P,Pfeat,Q,Qfeat,scope,hits,confidence,`related forms`,exceptions) |> 
  mutate(
    related_forms_list = str_split(`related forms`, ','),
    exceptions_list = str_split(exceptions, ', '),
  ) |> 
  unnest(related_forms_list) |>
  mutate(ahpa = str_replace_all(related_forms_list, c(' ' = '', '»' = ''))) |> 
  # we combine with celex so we have the orthographic forms!
  left_join(celex2) |> 
  group_by(rule,Change,P,Pfeat,Q,Qfeat,scope,hits,confidence) |> 
  # we glue together related forms into a string vector
  mutate(related_forms = paste(orth, collapse = ', ')) |> 
  distinct(rule,rule_id,Change,P,Pfeat,Q,Qfeat,scope,hits,confidence,exceptions_list,related_forms) |> 
  ungroup() |> 
  unnest(exceptions_list) |>
  mutate(ahpa = str_replace_all(exceptions_list, c(' ' = '', '»' = ''))) |> 
  left_join(celex2) |> 
  # we've done the same for exceptions, now we tidy it up
  group_by(rule,rule_id,Change,P,Pfeat,Q,Qfeat,scope,hits,confidence,related_forms) |> 
  mutate(exceptions = paste(orth, collapse = ', ')) |> 
  distinct(rule,rule_id,Change,P,Pfeat,Q,Qfeat,scope,hits,confidence,related_forms,exceptions) |> 
  ungroup()

# combine rules with nice related form and exception list
rules2 = rules |> 
  select(-`related forms`,-exceptions) |> 
  left_join(rules_forms)

# so some rules are there twice, once B==t, once B==d. otherwise completely identical. so we can keep the d ones and drop the t ones. this makes no practical difference.
rules_filt = rules2 |> 
  distinct(rule, rule_id, A, B, scope, hits, confidence, related_forms, exceptions) |> 
  group_by(scope, hits, confidence, related_forms, exceptions) |> 
  arrange(B) |> 
  slice(1) |> 
  ungroup()

# we get tidy rules
rules3 = rules2 |> 
  inner_join(rules_filt)

# we take Pfeat which is the left hand side of the structural description
prules = rules3 |> 
  distinct(Pfeat) |> 
  mutate(segment = str_replace_all(Pfeat, '[\\[\\]]', '')) |> 
  # we split the segments into rows
  separate_rows(segment, sep = ', ') |> 
  # nest the rows
  nest(data = segment) |> 
  # get the phonological features which describe those segments as a natural class. where there's any
  mutate(
    Pnatural_class = map_chr(data, ~ 
                            getFeatures(.)
                          )
  ) |> 
  # grab original col and natural class
  distinct(Pfeat,Pnatural_class)

# do the same for Q, the right-hand side of the structural description
qrules = rules |> 
  distinct(rule_id,Qfeat) |> 
  mutate(segment = str_replace_all(Qfeat, '[\\[\\]]', '')) |> 
  separate_rows(segment, sep = ', ') |> 
  nest(data = segment) |> 
  mutate(
    Qnatural_class = map_chr(data, ~ 
                          getFeatures(.)
    )
  ) |> 
  distinct(Qfeat,Qnatural_class)

# combine everything.
rules4 = rules3 |> 
  left_join(prules) |> 
  left_join(qrules)

# check missing rule descriptions
rules4 %<>% 
  mutate(
    Pnatural_class = case_when(
      Pfeat == "[2, 3, 4, 6, @, A, E, Q, V, a, e, o, {, »]" ~ '[mid-open vowel]',
      Pfeat == "[2, 3, 4, 6, @, A, D, E, I, N, Q, U, V, Z, _, a, b, d, e, g, i, j, l, m, n, o, r, u, v, w, z, {, »]" ~ '[non-voiceless obstruent]',
      Pfeat == "[2, 3, 4, 6, @, A, D, E, I, Q, S, T, U, V, Z, a, e, f, h, i, j, l, o, r, s, u, v, w, z, {, »]" ~ '[non-stop]',
      Pfeat == "[2, 3, 4, 6, @, A, E, I, Q, U, V, a, e, i, j, l, o, r, u, w, {, »]" ~ '[vowel or approximant]',
      Pfeat == "[2, 3, 4, 6, @, A, E, I, Q, U, V, a, e, i, j, o, r, u, w, {, »]" ~ '[vowel or non-lateral approximant]',
      T ~ Pnatural_class
    ),
    rule_left_side = case_when(
      is.na(P) ~ glue('{Pnatural_class}'),
      !is.na(P) ~ glue('{Pnatural_class} {P}')
    ),
    rule_right_side = case_when(
      is.na(Q) ~ glue('{Qnatural_class}'),
      !is.na(Q) ~ glue('{Q} {Qnatural_class}')
    ),
    rule_tidy = glue('{A} -> {B} / {rule_left_side} _ {rule_right_side}')
  )

# we now have rules with phonological features specifying the structural descriptions, like in the SPE or whatever! and scope and hits lists using english orthography.

# -- write -- #

write_tsv(rules4, 'dat/rules_fancy.tsv')
