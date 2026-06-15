-- =====================================================
--  DOMOTIHOME – Base de données complète
--  Projet académique – Groupe 53 – IUT de Douala
--  Tamen Stevine Dianelle | Brayan Ngalamo | Yann Tatsi
--  Génération : 2025
-- =====================================================

CREATE DATABASE IF NOT EXISTS domotihome
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE domotihome;

-- =====================================================
-- 1. UTILISATEURS
-- =====================================================
CREATE TABLE utilisateurs (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nom           VARCHAR(80)  NOT NULL,
  prenom        VARCHAR(80)  NOT NULL,
  email         VARCHAR(150) NOT NULL UNIQUE,
  mot_de_passe  VARCHAR(255) NOT NULL,          -- bcrypt hash
  telephone     VARCHAR(20),
  role          ENUM('admin','proprietaire','invité') NOT NULL DEFAULT 'proprietaire',
  statut        ENUM('actif','suspendu','en attente') NOT NULL DEFAULT 'actif',
  avatar_url    VARCHAR(255),
  token_reset   VARCHAR(255),
  token_expire  DATETIME,
  cree_le       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  mis_a_jour    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- =====================================================
-- 2. MAISONS
-- =====================================================
CREATE TABLE maisons (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nom         VARCHAR(100) NOT NULL,
  adresse     TEXT,
  ville       VARCHAR(80),
  pays        VARCHAR(60)  DEFAULT 'Cameroun',
  latitude    DECIMAL(10,7),
  longitude   DECIMAL(10,7),
  image_url   VARCHAR(255),
  cree_le     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Relation propriétaire ↔ maison (plusieurs utilisateurs par maison)
CREATE TABLE maison_utilisateurs (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  maison_id     INT UNSIGNED NOT NULL,
  utilisateur_id INT UNSIGNED NOT NULL,
  role          ENUM('proprietaire','invité','gardien') DEFAULT 'proprietaire',
  FOREIGN KEY (maison_id)      REFERENCES maisons(id)      ON DELETE CASCADE,
  FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE,
  UNIQUE KEY uniq_maison_user (maison_id, utilisateur_id)
);

-- =====================================================
-- 3. PIÈCES
-- =====================================================
CREATE TABLE pieces (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  maison_id   INT UNSIGNED NOT NULL,
  nom         VARCHAR(80)  NOT NULL,         -- "Salon", "Cuisine", etc.
  icone       VARCHAR(50)  DEFAULT 'fa-door-open',
  etage       TINYINT UNSIGNED DEFAULT 0,
  image_url   VARCHAR(255),
  cree_le     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (maison_id) REFERENCES maisons(id) ON DELETE CASCADE
);

-- =====================================================
-- 4. APPAREILS
-- =====================================================
CREATE TABLE types_appareils (
  id    TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nom   VARCHAR(60) NOT NULL,     -- "Lumière", "Caméra", "Thermostat", etc.
  icone VARCHAR(50)
);

INSERT INTO types_appareils (nom, icone) VALUES
  ('Lumière',         'fa-lightbulb'),
  ('Climatisation',   'fa-temperature-half'),
  ('Caméra',          'fa-video'),
  ('Serrure',         'fa-lock'),
  ('Détecteur',       'fa-radar'),
  ('Prise connectée', 'fa-plug'),
  ('Volet roulant',   'fa-blinds'),
  ('Portail',         'fa-gate');

CREATE TABLE appareils (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  piece_id        INT UNSIGNED NOT NULL,
  type_id         TINYINT UNSIGNED NOT NULL,
  nom             VARCHAR(100) NOT NULL,
  marque          VARCHAR(80),
  modele          VARCHAR(80),
  adresse_mac     VARCHAR(17) UNIQUE,
  protocole       ENUM('WiFi','Bluetooth','Zigbee','Z-Wave','Autre') DEFAULT 'WiFi',
  statut          ENUM('actif','inactif','erreur','hors_ligne') DEFAULT 'inactif',
  est_allume      TINYINT(1) NOT NULL DEFAULT 0,
  valeur_courante VARCHAR(50),           -- "24°C", "75%", "ON", etc.
  firmware        VARCHAR(30),
  cree_le         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (piece_id) REFERENCES pieces(id) ON DELETE CASCADE,
  FOREIGN KEY (type_id)  REFERENCES types_appareils(id)
);

-- =====================================================
-- 5. COMMANDES
-- =====================================================
CREATE TABLE commandes (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  utilisateur_id  INT UNSIGNED NOT NULL,
  appareil_id     INT UNSIGNED NOT NULL,
  action          VARCHAR(60)  NOT NULL,   -- "allumer", "éteindre", "set_temp:22", etc.
  valeur          VARCHAR(50),             -- valeur envoyée (ex. "22" pour thermostat)
  source          ENUM('app','routine','voix','api') DEFAULT 'app',
  statut          ENUM('envoyée','exécutée','échouée') DEFAULT 'envoyée',
  executee_le     DATETIME,
  cree_le         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id),
  FOREIGN KEY (appareil_id)    REFERENCES appareils(id) ON DELETE CASCADE
);

-- =====================================================
-- 6. CAPTEURS & DONNÉES IoT
-- =====================================================
CREATE TABLE capteurs (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  piece_id    INT UNSIGNED NOT NULL,
  type        ENUM('température','humidité','mouvement','luminosité','fumée','CO2') NOT NULL,
  nom         VARCHAR(80),
  unite       VARCHAR(10),      -- "°C", "%", "lux", "ppm"
  valeur_min  DECIMAL(8,2),
  valeur_max  DECIMAL(8,2),
  cree_le     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (piece_id) REFERENCES pieces(id) ON DELETE CASCADE
);

CREATE TABLE mesures_capteurs (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  capteur_id  INT UNSIGNED NOT NULL,
  valeur      DECIMAL(10,4) NOT NULL,
  enregistree DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (capteur_id) REFERENCES capteurs(id) ON DELETE CASCADE,
  INDEX idx_capteur_date (capteur_id, enregistree)
);

-- =====================================================
-- 7. ROUTINES / AUTOMATISATIONS
-- =====================================================
CREATE TABLE routines (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  maison_id       INT UNSIGNED NOT NULL,
  createur_id     INT UNSIGNED NOT NULL,
  nom             VARCHAR(100) NOT NULL,    -- "Mode nuit", "Réveil"
  description     TEXT,
  est_active      TINYINT(1) DEFAULT 1,
  declencheur     ENUM('heure','condition','manuel','geofence') DEFAULT 'heure',
  heure_trigger   TIME,                     -- si déclencheur = 'heure'
  jours           SET('Lun','Mar','Mer','Jeu','Ven','Sam','Dim'),
  condition_json  JSON,                     -- {"capteur_id": 3, "operateur": ">", "valeur": 30}
  cree_le         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (maison_id)    REFERENCES maisons(id)      ON DELETE CASCADE,
  FOREIGN KEY (createur_id)  REFERENCES utilisateurs(id)
);

-- Actions incluses dans une routine
CREATE TABLE routine_actions (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  routine_id   INT UNSIGNED NOT NULL,
  appareil_id  INT UNSIGNED NOT NULL,
  action       VARCHAR(60)  NOT NULL,
  valeur       VARCHAR(50),
  delai_sec    INT UNSIGNED DEFAULT 0,    -- délai après déclenchement
  ordre        TINYINT UNSIGNED DEFAULT 0,
  FOREIGN KEY (routine_id)  REFERENCES routines(id)  ON DELETE CASCADE,
  FOREIGN KEY (appareil_id) REFERENCES appareils(id) ON DELETE CASCADE
);

-- =====================================================
-- 8. HISTORIQUE GLOBAL
-- =====================================================
CREATE TABLE historique (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  utilisateur_id  INT UNSIGNED,
  appareil_id     INT UNSIGNED,
  routine_id      INT UNSIGNED,
  type_evenement  ENUM('commande','alerte','connexion','déconnexion','routine','systeme') NOT NULL,
  description     TEXT NOT NULL,
  cree_le         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_histo_date (cree_le),
  FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE SET NULL,
  FOREIGN KEY (appareil_id)    REFERENCES appareils(id)    ON DELETE SET NULL
);

-- =====================================================
-- 9. NOTIFICATIONS
-- =====================================================
CREATE TABLE notifications (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  utilisateur_id  INT UNSIGNED NOT NULL,
  titre           VARCHAR(150) NOT NULL,
  message         TEXT         NOT NULL,
  type            ENUM('info','alerte','succès','erreur') DEFAULT 'info',
  lue             TINYINT(1) DEFAULT 0,
  appareil_id     INT UNSIGNED,
  lien_action     VARCHAR(255),
  cree_le         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE,
  FOREIGN KEY (appareil_id)    REFERENCES appareils(id)    ON DELETE SET NULL
);

-- =====================================================
-- 10. CONSOMMATION ÉNERGÉTIQUE
-- =====================================================
CREATE TABLE consommation_energie (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  appareil_id  INT UNSIGNED NOT NULL,
  kwh          DECIMAL(8,4) NOT NULL,
  cout_fcfa    DECIMAL(10,2),
  periode_debut DATETIME NOT NULL,
  periode_fin   DATETIME NOT NULL,
  FOREIGN KEY (appareil_id) REFERENCES appareils(id) ON DELETE CASCADE,
  INDEX idx_conso_appareil_date (appareil_id, periode_debut)
);

-- =====================================================
-- 11. TOKENS PUSH (notifications mobiles)
-- =====================================================
CREATE TABLE push_tokens (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  utilisateur_id  INT UNSIGNED NOT NULL,
  token           VARCHAR(300) NOT NULL UNIQUE,
  plateforme      ENUM('android','ios','web') NOT NULL,
  actif           TINYINT(1) DEFAULT 1,
  cree_le         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE
);

-- =====================================================
-- DONNÉES DE TEST (seed)
-- =====================================================

-- Utilisateurs
INSERT INTO utilisateurs (nom, prenom, email, mot_de_passe, role) VALUES
  ('Dianelle', 'Stevine', 'stevine@domotihome.cm',
   '$2y$10$examplehashbcryptStevine', 'proprietaire'),
  ('Tchamedeu', 'Brayan', 'brayan@domotihome.cm',
   '$2y$10$examplehashbcryptBrayan',  'admin'),
  ('Njike', 'Yann', 'yann@domotihome.cm',
   '$2y$10$examplehashbcryptYann',    'proprietaire');

-- Maison
INSERT INTO maisons (nom, adresse, ville) VALUES
  ('Maison Stevine', 'Rue de la Paix 12', 'Douala'),
  ('Appartement Yann', 'Av. de l\'Indépendance 45', 'Douala');

-- Lier utilisateurs ↔ maisons
INSERT INTO maison_utilisateurs (maison_id, utilisateur_id, role) VALUES
  (1, 1, 'proprietaire'), (1, 2, 'invité'),
  (2, 3, 'proprietaire');

-- Pièces
INSERT INTO pieces (maison_id, nom, icone, etage) VALUES
  (1, 'Salon',           'fa-couch',           0),
  (1, 'Cuisine',         'fa-utensils',         0),
  (1, 'Chambre',         'fa-bed',              1),
  (1, 'Salle de bain',   'fa-bath',             1),
  (1, 'Garage',          'fa-car',              0),
  (2, 'Salon',           'fa-couch',            0),
  (2, 'Chambre',         'fa-bed',              1);

-- Appareils
INSERT INTO appareils (piece_id, type_id, nom, marque, statut, est_allume, valeur_courante) VALUES
  (1, 1, 'Lumière plafond salon',    'Philips Hue',   'actif',  1, 'ON'),
  (1, 2, 'Clim salon',               'Samsung Wind',  'actif',  1, '24°C'),
  (1, 3, 'Caméra salon',             'Arlo Pro',      'actif',  1, 'EN LIGNE'),
  (2, 1, 'Lumière cuisine',          'IKEA Tradfri',  'actif',  1, 'ON'),
  (3, 1, 'Lumière chambre',          'Philips Hue',   'inactif',0, 'OFF'),
  (3, 2, 'Clim chambre',             'LG Dual',       'inactif',0, 'OFF'),
  (5, 8, 'Portail garage',           'Somfy',         'actif',  0, 'FERMÉ'),
  (5, 3, 'Caméra garage',            'Hikvision',     'actif',  1, 'EN LIGNE');

-- Capteurs
INSERT INTO capteurs (piece_id, type, nom, unite) VALUES
  (1, 'température', 'Temp. salon',    '°C'),
  (1, 'humidité',    'Hum. salon',     '%'),
  (3, 'mouvement',   'PIR chambre',    NULL),
  (5, 'mouvement',   'PIR garage',     NULL);

-- Quelques mesures
INSERT INTO mesures_capteurs (capteur_id, valeur) VALUES
  (1, 24.3), (1, 24.1), (1, 23.8),
  (2, 62.0), (2, 60.5);

-- Routine exemple
INSERT INTO routines (maison_id, createur_id, nom, description, declencheur, heure_trigger, jours) VALUES
  (1, 1, 'Mode nuit', 'Éteint toutes les lumières et arme la sécurité à 22h',
   'heure', '22:00:00', 'Lun,Mar,Mer,Jeu,Ven,Sam,Dim'),
  (1, 1, 'Réveil doux', 'Allume lumière chambre à 6h30 du matin',
   'heure', '06:30:00', 'Lun,Mar,Mer,Jeu,Ven');

-- Actions de routine
INSERT INTO routine_actions (routine_id, appareil_id, action, valeur, ordre) VALUES
  (1, 1, 'éteindre', NULL, 1),
  (1, 4, 'éteindre', NULL, 2),
  (2, 5, 'allumer',  '30%', 1);

-- Notifications
INSERT INTO notifications (utilisateur_id, titre, message, type) VALUES
  (1, 'Mouvement détecté', 'Un mouvement a été détecté dans le garage à 23h14.', 'alerte'),
  (1, 'Routine activée',   'La routine "Mode nuit" a été exécutée avec succès.',   'succès'),
  (1, 'Appareil hors ligne','La caméra du couloir est hors ligne depuis 1h.',       'erreur');

-- =====================================================
-- VUES UTILES
-- =====================================================

-- Vue : état de tous les appareils avec leur pièce
CREATE OR REPLACE VIEW v_appareils_etat AS
SELECT
  a.id,
  m.nom  AS maison,
  p.nom  AS piece,
  t.nom  AS type,
  a.nom,
  a.est_allume,
  a.valeur_courante,
  a.statut,
  a.protocole
FROM appareils a
JOIN pieces          p ON a.piece_id = p.id
JOIN maisons         m ON p.maison_id = m.id
JOIN types_appareils t ON a.type_id   = t.id;

-- Vue : historique des commandes lisible
CREATE OR REPLACE VIEW v_historique_commandes AS
SELECT
  c.id,
  CONCAT(u.prenom, ' ', u.nom) AS utilisateur,
  a.nom  AS appareil,
  p.nom  AS piece,
  c.action,
  c.valeur,
  c.source,
  c.statut,
  c.cree_le
FROM commandes c
JOIN utilisateurs u ON c.utilisateur_id = u.id
JOIN appareils    a ON c.appareil_id    = a.id
JOIN pieces       p ON a.piece_id       = p.id
ORDER BY c.cree_le DESC;

-- Vue : consommation par appareil (jour courant)
CREATE OR REPLACE VIEW v_conso_jour AS
SELECT
  a.nom  AS appareil,
  p.nom  AS piece,
  SUM(ce.kwh) AS kwh_total,
  SUM(ce.cout_fcfa) AS cout_fcfa
FROM consommation_energie ce
JOIN appareils a ON ce.appareil_id = a.id
JOIN pieces    p ON a.piece_id     = p.id
WHERE DATE(ce.periode_debut) = CURDATE()
GROUP BY a.id;

-- =====================================================
-- INDEX SUPPLÉMENTAIRES
-- =====================================================
ALTER TABLE notifications ADD INDEX idx_notif_user_lue (utilisateur_id, lue);
ALTER TABLE commandes      ADD INDEX idx_cmd_user_date  (utilisateur_id, cree_le);
ALTER TABLE appareils      ADD INDEX idx_app_piece      (piece_id);
