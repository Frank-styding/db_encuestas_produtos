-- =========================================================
-- CREACIÓN DE TABLAS (ACTUALIZADO - MODEL → PRODUCT)
-- =========================================================

CREATE TABLE "Admin" (
    admin_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    restore_code VARCHAR(255),
    created_at TIMESTAMP DEFAULT now()
);

-- CAMBIADO: Model_Group → Product_Group
CREATE TABLE "Product_Group" (
    product_group_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    admin_id uuid NOT NULL REFERENCES "Admin"(admin_id) ON DELETE CASCADE
);

-- CAMBIADO: Model → Product
CREATE TABLE "Product" (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    keyshotXR_url TEXT NOT NULL,
    product_group_id INT NOT NULL REFERENCES "Product_Group"(product_group_id) ON DELETE CASCADE
);

-- CAMBIADO: model_id → product_id
CREATE TABLE "Image" (
    image_id SERIAL PRIMARY KEY,
    url TEXT NOT NULL,
    product_id INT NOT NULL REFERENCES "Product"(product_id) ON DELETE CASCADE
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

-- CAMBIADO: num_model → num_product
CREATE TABLE "Question" (
    question_id SERIAL PRIMARY KEY,
    question_text TEXT NOT NULL,
    survey_id INT NOT NULL REFERENCES "Survey"(survey_id) ON DELETE CASCADE,
    num_product INT  -- Columna actualizada
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

-- CAMBIADO: Survey_Model → Survey_Product, model_id → product_id
CREATE TABLE "Survey_Product" (
    survey_product_id SERIAL PRIMARY KEY,
    survey_id INT NOT NULL REFERENCES "Survey"(survey_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES "Product"(product_id) ON DELETE CASCADE
);

-- CAMBIADO: Question_Model → Question_Product, model_id → product_id
CREATE TABLE "Question_Product" (
    question_product_id SERIAL PRIMARY KEY,
    question_id INT NOT NULL REFERENCES "Question"(question_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES "Product"(product_id) ON DELETE CASCADE
);

-- =========================================================
-- HABILITAR ROW LEVEL SECURITY
-- =========================================================

/* ALTER TABLE "Admin" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Product_Group" ENABLE ROW LEVEL SECURITY;  -- Actualizado
ALTER TABLE "Product" ENABLE ROW LEVEL SECURITY;        -- Actualizado
ALTER TABLE "Image" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Survey_Group" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Survey" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Question" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "User_Account" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Answer" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Survey_Product" ENABLE ROW LEVEL SECURITY;  -- Actualizado
ALTER TABLE "Question_Product" ENABLE ROW LEVEL SECURITY; -- Actualizado
 */
-- =========================================================
-- 🔐 POLÍTICAS DE ADMINISTRADORES (ACTUALIZADAS)
-- =========================================================

CREATE POLICY "Admins can read and update own data"
ON "Admin"
FOR ALL
USING (auth.uid() = admin_id);

-- CAMBIADO: Model_Group → Product_Group
CREATE POLICY "Admins manage their own product groups"
ON "Product_Group"
FOR ALL
USING (auth.uid() = admin_id);

-- CAMBIADO: Model → Product, model_group_id → product_group_id
CREATE POLICY "Admins manage their own products"
ON "Product"
FOR ALL
USING (
  auth.uid() = (
    SELECT pg.admin_id FROM "Product_Group" pg 
    WHERE pg.product_group_id = "Product".product_group_id
  )
);

-- CAMBIADO: Referencias actualizadas a Product
CREATE POLICY "Admins manage their own images"
ON "Image"
FOR ALL
USING (
  auth.uid() = (
    SELECT pg.admin_id
    FROM "Product_Group" pg
    JOIN "Product" p ON p.product_group_id = pg.product_group_id
    WHERE p.product_id = "Image".product_id
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
-- 🔐 POLÍTICAS DE USER_ACCOUNT
-- =========================================================

CREATE POLICY "Users can view own account" 
ON "User_Account" 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own account" 
ON "User_Account" 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own account" 
ON "User_Account" 
FOR UPDATE 
USING (auth.uid() = user_id);

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
-- 🔐 POLÍTICAS DE TABLAS DE RELACIÓN (ACTUALIZADAS)
-- =========================================================

-- CAMBIADO: Survey_Model → Survey_Product, model_id → product_id
CREATE POLICY "Admins manage survey-product links"
ON "Survey_Product"
FOR ALL
USING (
  auth.uid() IN (
    SELECT sg.admin_id
    FROM "Survey_Group" sg
    JOIN "Survey" s ON s.survey_group_id = sg.survey_group_id
    WHERE s.survey_id = "Survey_Product".survey_id
  )
);

-- CAMBIADO: Survey_Model → Survey_Product
CREATE POLICY "Public can view survey-products from public surveys"
ON "Survey_Product"
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM "Survey" s
    WHERE s.survey_id = "Survey_Product".survey_id
    AND s.is_public = true
  )
);

-- CAMBIADO: Question_Model → Question_Product, model_id → product_id
CREATE POLICY "Admins manage question-product links"
ON "Question_Product"
FOR ALL
USING (
  auth.uid() IN (
    SELECT sg.admin_id
    FROM "Survey_Group" sg
    JOIN "Survey" s ON s.survey_group_id = sg.survey_group_id
    JOIN "Question" q ON q.survey_id = s.survey_id
    WHERE q.question_id = "Question_Product".question_id
  )
);

-- CAMBIADO: Question_Model → Question_Product
CREATE POLICY "Public can view question-products from public surveys"
ON "Question_Product"
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM "Question" q
    JOIN "Survey" s ON q.survey_id = s.survey_id
    WHERE q.question_id = "Question_Product".question_id
    AND s.is_public = true
  )
);

-- =========================================================
-- 🔥 SCRIPT DE ELIMINACIÓN ACTUALIZADO
-- =========================================================
/*
DROP TABLE IF EXISTS "Question_Product" CASCADE;
DROP TABLE IF EXISTS "Survey_Product" CASCADE;
DROP TABLE IF EXISTS "Answer" CASCADE;
DROP TABLE IF EXISTS "Question" CASCADE;
DROP TABLE IF EXISTS "Image" CASCADE;
DROP TABLE IF EXISTS "Survey" CASCADE;
DROP TABLE IF EXISTS "Product" CASCADE;
DROP TABLE IF EXISTS "Product_Group" CASCADE;
DROP TABLE IF EXISTS "Survey_Group" CASCADE;
DROP TABLE IF EXISTS "User_Account" CASCADE;
DROP TABLE IF EXISTS "Admin" CASCADE;
*/
