-- =========================================================
-- 🌐 PRODUCT SURVEY APP - SQL FINAL (Sin num_images ni is_active)
-- =========================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- 🧑‍💼 ADMINISTRADORES
-- =========================================================
CREATE TABLE "Admin" (
    admin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    restore_code VARCHAR(255),
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- =========================================================
-- 🧩 PRODUCT GROUPS
-- =========================================================
CREATE TABLE "Product_Group" (
    product_group_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    admin_id UUID NOT NULL REFERENCES "Admin"(admin_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- =========================================================
-- 🛍️ PRODUCTS
-- =========================================================
CREATE TABLE "Product" (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    weight DECIMAL(10,2),
    product_group_id INT NOT NULL REFERENCES "Product_Group"(product_group_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- =========================================================
-- 🖼️ IMAGES
-- =========================================================
CREATE TABLE "Image" (
    image_id SERIAL PRIMARY KEY,
    url TEXT NOT NULL,
    path TEXT NOT NULL,
    weight DECIMAL(10,2),
    dimension VARCHAR(100),
    product_id INT NOT NULL REFERENCES "Product"(product_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- =========================================================
-- 📋 SURVEY GROUPS
-- =========================================================
CREATE TABLE "Survey_Group" (
    survey_group_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    admin_id UUID NOT NULL REFERENCES "Admin"(admin_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- =========================================================
-- 🧾 SURVEYS
-- =========================================================
CREATE TABLE "Survey" (
    survey_id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    survey_group_id INT NOT NULL REFERENCES "Survey_Group"(survey_group_id) ON DELETE CASCADE,
    is_public BOOLEAN DEFAULT true,
    password VARCHAR(255),
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- =========================================================
-- ❓ QUESTIONS
-- =========================================================
CREATE TABLE "Question" (
    question_id SERIAL PRIMARY KEY,
    question_text TEXT NOT NULL,
    survey_id INT NOT NULL REFERENCES "Survey"(survey_id) ON DELETE CASCADE,
    num_product INT REFERENCES "Product"(product_id) ON DELETE RESTRICT,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- =========================================================
-- 👤 USERS
-- =========================================================
CREATE TABLE "User_Account" (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100),
    email VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- =========================================================
-- 🗳️ ANSWERS
-- =========================================================
CREATE TABLE "Answer" (
    answer_id SERIAL PRIMARY KEY,
    question_id INT NOT NULL REFERENCES "Question"(question_id) ON DELETE CASCADE,
    user_id UUID REFERENCES "User_Account"(user_id) ON DELETE SET NULL,
    answer_value INT CHECK (answer_value >= 0),
    comment VARCHAR (200),
    is_anonymous BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- =========================================================
-- 🔗 RELACIONES MUCHOS A MUCHOS
-- =========================================================
CREATE TABLE "Survey_Product" (
    survey_product_id SERIAL PRIMARY KEY,
    survey_id INT NOT NULL REFERENCES "Survey"(survey_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES "Product"(product_id) ON DELETE CASCADE,
    UNIQUE (survey_id, product_id)
);

CREATE TABLE "Question_Product" (
    question_product_id SERIAL PRIMARY KEY,
    question_id INT NOT NULL REFERENCES "Question"(question_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES "Product"(product_id) ON DELETE CASCADE,
    UNIQUE (question_id, product_id)
);

-- =========================================================
-- ⚙️ ROW LEVEL SECURITY (RLS)
-- =========================================================
ALTER TABLE "Admin" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Product_Group" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Product" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Image" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Survey_Group" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Survey" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Question" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "User_Account" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Answer" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Survey_Product" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Question_Product" ENABLE ROW LEVEL SECURITY;

-- =========================================================
-- 🔐 POLÍTICAS DE SEGURIDAD
-- =========================================================
-- (Se mantienen igual, ya que no dependen de num_images ni is_active)
-- =========================================================

-- 👑 ADMIN
CREATE POLICY "Admin can manage self"
ON "Admin"
FOR ALL
USING (auth.uid() = admin_id);

-- 🧩 PRODUCT GROUP
CREATE POLICY "Admins manage own product groups"
ON "Product_Group"
FOR ALL
USING (auth.uid() = admin_id);

-- 🛍️ PRODUCT
CREATE POLICY "Admins manage own products"
ON "Product"
FOR ALL
USING (
    auth.uid() = (
        SELECT pg.admin_id FROM "Product_Group" pg
        WHERE pg.product_group_id = "Product".product_group_id
    )
);

-- 🖼️ IMAGE
CREATE POLICY "Admins manage images of their products"
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

-- 📋 SURVEY GROUP
CREATE POLICY "Admins manage own survey groups"
ON "Survey_Group"
FOR ALL
USING (auth.uid() = admin_id);

-- 🧾 SURVEY
CREATE POLICY "Admins manage own surveys"
ON "Survey"
FOR ALL
USING (
    auth.uid() = (
        SELECT sg.admin_id
        FROM "Survey_Group" sg
        WHERE sg.survey_group_id = "Survey".survey_group_id
    )
);

CREATE POLICY "Public can view public surveys"
ON "Survey"
FOR SELECT
USING (is_public = true);

-- ❓ QUESTION
CREATE POLICY "Public can read questions from public surveys"
ON "Question"
FOR SELECT
USING (
    "Question".survey_id IN (
        SELECT survey_id FROM "Survey" WHERE is_public = true
    )
);

-- 👤 USER ACCOUNT
CREATE POLICY "Users manage own account"
ON "User_Account"
FOR ALL
USING (auth.uid() = user_id);

-- 🗳️ ANSWER
CREATE POLICY "Authenticated users insert their answers"
ON "Answer"
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Anonymous users can insert"
ON "Answer"
FOR INSERT
WITH CHECK (is_anonymous = true);

CREATE POLICY "Users can view own answers"
ON "Answer"
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Admins view all answers of their surveys"
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

-- 🔗 SURVEY_PRODUCT
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

CREATE POLICY "Public view public survey-product links"
ON "Survey_Product"
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM "Survey" s
        WHERE s.survey_id = "Survey_Product".survey_id
        AND s.is_public = true
    )
);

-- 🔗 QUESTION_PRODUCT
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

CREATE POLICY "Public view public question-product links"
ON "Question_Product"
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM "Question" q
        JOIN "Survey" s ON q.survey_id = s.survey_id
        WHERE q.question_id = "Question_Product".question_id
        AND s.is_public = true
    )
);

-- =========================================================
-- ⚙️ FUNCIONES Y TRIGGERS
-- =========================================================

-- 🕒 Actualizar updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_admin_updated_at BEFORE UPDATE ON "Admin" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_product_group_updated_at BEFORE UPDATE ON "Product_Group" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_product_updated_at BEFORE UPDATE ON "Product" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_image_updated_at BEFORE UPDATE ON "Image" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_survey_group_updated_at BEFORE UPDATE ON "Survey_Group" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_survey_updated_at BEFORE UPDATE ON "Survey" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_question_updated_at BEFORE UPDATE ON "Question" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_user_updated_at BEFORE UPDATE ON "User_Account" FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_answer_updated_at BEFORE UPDATE ON "Answer" FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- 🧨 DROP SCRIPT (LIMPIEZA)
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
