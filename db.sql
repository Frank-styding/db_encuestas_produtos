-- =========================================================
-- CREACIÓN DE TABLAS (CORREGIDO)
-- =========================================================

-- =========================================================
-- CREACIÓN DE TABLAS (CORREGIDO)
-- =========================================================

CREATE TABLE "Admin" (
    admin_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    restore_code VARCHAR(255),
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE "Model_Group" (
    model_group_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    admin_id uuid NOT NULL REFERENCES "Admin"(admin_id) ON DELETE CASCADE
);

CREATE TABLE "Model" (
    model_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    keyshotXR_url TEXT NOT NULL,
    model_group_id INT NOT NULL REFERENCES "Model_Group"(model_group_id) ON DELETE CASCADE
);

CREATE TABLE "Image" (
    image_id SERIAL PRIMARY KEY,
    url TEXT NOT NULL,
    model_id INT NOT NULL REFERENCES "Model"(model_id) ON DELETE CASCADE
);

CREATE TABLE "Survey_Group" (
    survey_group_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    admin_id uuid NOT NULL REFERENCES "Admin"(admin_id) ON DELETE CASCADE
);

CREATE TABLE "Survey" (
    survey_id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    survey_group_id INT NOT NULL REFERENCES "Survey_Group"(survey_group_id) ON DELETE CASCADE,
    is_public BOOLEAN DEFAULT TRUE,
    password VARCHAR(255),
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE "Question" (
    question_id SERIAL PRIMARY KEY,
    question_text TEXT NOT NULL,
    survey_id INT NOT NULL REFERENCES "Survey"(survey_id) ON DELETE CASCADE,
    num_model INT  -- Nueva columna agregada
);

CREATE TABLE "User_Account" (
    user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100),
    email VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE "Answer" (
    answer_id SERIAL PRIMARY KEY,
    question_id INT NOT NULL REFERENCES "Question"(question_id) ON DELETE CASCADE,
    user_id uuid REFERENCES "User_Account"(user_id) ON DELETE SET NULL,
    answer_value INT CHECK (answer_value >= 0),
    is_anonymous BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE "Survey_Model" (
    survey_model_id SERIAL PRIMARY KEY,
    survey_id INT NOT NULL REFERENCES "Survey"(survey_id) ON DELETE CASCADE,
    model_id INT NOT NULL REFERENCES "Model"(model_id) ON DELETE CASCADE
);

CREATE TABLE "Question_Model" (
    question_model_id SERIAL PRIMARY KEY,
    question_id INT NOT NULL REFERENCES "Question"(question_id) ON DELETE CASCADE,
    model_id INT NOT NULL REFERENCES "Model"(model_id) ON DELETE CASCADE
);

-- ... el resto del script (RLS y políticas) se mantiene igual ...
-- =========================================================
-- HABILITAR ROW LEVEL SECURITY
-- =========================================================

ALTER TABLE "Admin" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Model_Group" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Model" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Image" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Survey_Group" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Survey" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Question" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "User_Account" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Answer" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Survey_Model" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Question_Model" ENABLE ROW LEVEL SECURITY;

-- =========================================================
-- 🔐 POLÍTICAS DE ADMINISTRADORES
-- =========================================================

CREATE POLICY "Admins can read and update own data"
ON "Admin"
FOR ALL
USING (auth.uid() = admin_id);

CREATE POLICY "Admins manage their own model groups"
ON "Model_Group"
FOR ALL
USING (auth.uid() = admin_id);

CREATE POLICY "Admins manage their own models"
ON "Model"
FOR ALL
USING (
  auth.uid() = (
    SELECT mg.admin_id FROM "Model_Group" mg 
    WHERE mg.model_group_id = "Model".model_group_id
  )
);

CREATE POLICY "Admins manage their own images"
ON "Image"
FOR ALL
USING (
  auth.uid() = (
    SELECT mg.admin_id
    FROM "Model_Group" mg
    JOIN "Model" m ON m.model_group_id = mg.model_group_id
    WHERE m.model_id = "Image".model_id
  )
);

CREATE POLICY "Admins manage their own survey groups"
ON "Survey_Group"
FOR ALL
USING (auth.uid() = admin_id);

CREATE POLICY "Admins manage their own surveys"
ON "Survey"
FOR ALL
USING (
  auth.uid() = (
    SELECT sg.admin_id
    FROM "Survey_Group" sg
    WHERE sg.survey_group_id = "Survey".survey_group_id
  )
);

-- =========================================================
-- 🔐 POLÍTICAS PÚBLICAS
-- =========================================================

CREATE POLICY "Public can view public surveys"
ON "Survey"
FOR SELECT
USING (is_public = true);

CREATE POLICY "Public can read questions from visible surveys"
ON "Question"
FOR SELECT
USING (
  "Question".survey_id IN (
    SELECT survey_id FROM "Survey" WHERE is_public = true
  )
);

-- =========================================================
-- 🔐 POLÍTICAS DE USER_ACCOUNT (NUEVAS)
-- =========================================================

-- Usuarios pueden ver solo su propia cuenta
CREATE POLICY "Users can view own account" 
ON "User_Account" 
FOR SELECT 
USING (auth.uid() = user_id);

-- Usuarios pueden insertar solo su propia cuenta
CREATE POLICY "Users can insert own account" 
ON "User_Account" 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Usuarios pueden actualizar solo su propia cuenta
CREATE POLICY "Users can update own account" 
ON "User_Account" 
FOR UPDATE 
USING (auth.uid() = user_id);

-- Administradores pueden gestionar todas las cuentas de usuario
CREATE POLICY "Admins can manage all user accounts" 
ON "User_Account" 
FOR ALL 
USING (
  auth.uid() IN (
    SELECT admin_id FROM "Admin"
  )
);

-- =========================================================
-- 🔐 POLÍTICAS DE RESPUESTAS (ANSWER)
-- =========================================================

CREATE POLICY "Authenticated users can insert their answers"
ON "Answer"
FOR INSERT
WITH CHECK (
  auth.uid() = user_id
);

CREATE POLICY "Anonymous users can insert answers"
ON "Answer"
FOR INSERT
WITH CHECK (is_anonymous = true);

CREATE POLICY "Users can view only their own answers"
ON "Answer"
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all answers from their surveys"
ON "Answer"
FOR SELECT
USING (
  auth.uid() IN (
    SELECT sg.admin_id
    FROM "Survey_Group" sg
    JOIN "Survey" s ON s.survey_group_id = sg.survey_group_id
    JOIN "Question" q ON q.survey_id = s.survey_id
    WHERE q.question_id = "Answer".question_id
  )
);

-- =========================================================
-- 🔐 POLÍTICAS DE TABLAS DE RELACIÓN
-- =========================================================

CREATE POLICY "Admins manage survey-model links"
ON "Survey_Model"
FOR ALL
USING (
  auth.uid() IN (
    SELECT sg.admin_id
    FROM "Survey_Group" sg
    JOIN "Survey" s ON s.survey_group_id = sg.survey_group_id
    WHERE s.survey_id = "Survey_Model".survey_id
  )
);

CREATE POLICY "Public can view survey-models from public surveys"
ON "Survey_Model"
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM "Survey" s
    WHERE s.survey_id = "Survey_Model".survey_id
    AND s.is_public = true
  )
);

CREATE POLICY "Admins manage question-model links"
ON "Question_Model"
FOR ALL
USING (
  auth.uid() IN (
    SELECT sg.admin_id
    FROM "Survey_Group" sg
    JOIN "Survey" s ON s.survey_group_id = sg.survey_group_id
    JOIN "Question" q ON q.survey_id = s.survey_id
    WHERE q.question_id = "Question_Model".question_id
  )
);

CREATE POLICY "Public can view question-models from public surveys"
ON "Question_Model"
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM "Question" q
    JOIN "Survey" s ON q.survey_id = s.survey_id
    WHERE q.question_id = "Question_Model".question_id
    AND s.is_public = true
  )
);

-- =========================================================
-- 🔥 ELIMINAR TODAS LAS TABLAS EN ORDEN CORRECTO
-- =========================================================

/* DROP TABLE IF EXISTS "Question_Model" CASCADE;
DROP TABLE IF EXISTS "Survey_Model" CASCADE;
DROP TABLE IF EXISTS "Answer" CASCADE;
DROP TABLE IF EXISTS "Question" CASCADE;
DROP TABLE IF EXISTS "Survey" CASCADE;
DROP TABLE IF EXISTS "Group_Survey" CASCADE;
DROP TABLE IF EXISTS "Image" CASCADE;
DROP TABLE IF EXISTS "Model" CASCADE;
DROP TABLE IF EXISTS "Model_Group" CASCADE;
DROP TABLE IF EXISTS "User_Account" CASCADE;
DROP TABLE IF EXISTS "Admin" CASCADE;
DROP TABLE IF EXISTS "User" CASCADE;
DROP TABLE IF EXISTS "Survey_Group" CASCADE; */
