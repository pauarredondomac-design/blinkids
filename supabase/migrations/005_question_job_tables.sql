-- ============================================================
-- FinQuest — Migración 005: Preguntas y trabajos educativos
-- ============================================================

-- 12. Banco de preguntas educativas
create table questions (
  id              uuid default uuid_generate_v4() primary key,
  world_id        uuid references worlds(id),   -- null = aplica a todos los mundos
  type            question_type not null,
  difficulty      difficulty_level not null,
  question_text   text not null,
  options         jsonb not null,               -- array de opciones según el tipo
  correct_answer  jsonb not null,               -- respuesta(s) correcta(s)
  coin_reward     integer default 10 check (coin_reward >= 0),
  xp_reward       integer default 5 check (xp_reward >= 0),
  explanation     text,                         -- explicación post-respuesta
  is_active       boolean default true,
  created_at      timestamptz default now()
);

-- Ejemplos de options/correct_answer por tipo:
-- multiple_choice: options=[{id,text,icon?},...], correct_answer="id_de_opcion"
-- true_false:      options=[{id:"t",text:"Verdadero"},{id:"f",text:"Falso"}], correct_answer="t"
-- drag_match:      options=[{left:[...],right:[...]}], correct_answer=[{leftId,rightId},...]
-- order_steps:     options=[{id,text},...], correct_answer=["id1","id2","id3",...]
-- fill_blank:      options=[{id,word},...], correct_answer="id_de_palabra"

-- 13. Respuestas del jugador (historial)
create table player_answers (
  id           uuid default uuid_generate_v4() primary key,
  user_id      uuid references profiles(id) on delete cascade not null,
  question_id  uuid references questions(id) not null,
  is_correct   boolean not null,
  answered_at  timestamptz default now()
);

create index idx_player_answers_user     on player_answers(user_id);
create index idx_player_answers_question on player_answers(question_id);

-- 14. Trabajos disponibles (mini-juegos por mundo)
create table jobs (
  id               uuid default uuid_generate_v4() primary key,
  world_id         uuid references worlds(id),
  name             text not null,
  description      text,
  instructions     jsonb,                        -- pasos e instrucciones del mini-juego
  coin_reward      integer not null check (coin_reward > 0),
  xp_reward        integer default 10 check (xp_reward >= 0),
  duration_seconds integer default 60 check (duration_seconds > 0),
  cooldown_minutes integer default 60 check (cooldown_minutes >= 0),
  image_url        text,
  is_active        boolean default true,
  created_at       timestamptz default now()
);

-- 15. Historial de trabajos completados
create table job_completions (
  id            uuid default uuid_generate_v4() primary key,
  user_id       uuid references profiles(id) on delete cascade not null,
  job_id        uuid references jobs(id) not null,
  coins_earned  integer not null check (coins_earned >= 0),
  completed_at  timestamptz default now()
);

create index idx_job_completions_user on job_completions(user_id);
create index idx_job_completions_job  on job_completions(job_id);
