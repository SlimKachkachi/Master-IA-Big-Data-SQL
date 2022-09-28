---Projet de ZANUTTO Sara et KACHKACHI Slim
---réalisé sur POSGRESQL sur PC 

---------------------------------------------------------------------------------------------------------------------
-----------SCHÉMA DE LA BASE DE DONNÉES------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------

---------création table des Series -----------------------------------------------------------------------------------
---------Contrainte demandée : unicité du nom de la série ------------------------------------------------------------
--------->doute sur la contrainte sur l'unicité de la PF pour une série donnée / on a choisi de l'imposer-------------
--------->une série a donc un nom unique et est diffusée par une unique PFF ------------------------------------------
--------Aucune contrainte demandée sur l'obligation de saisir les noms des séries et PF-------------------------------
---------> On a choisi d'imposer leur saisie pour éviter la gestion des 'Null' dans les requêtes par la suite---------
--------Aucune contrainte demandée sur la liste des plates-formes-----------------------------------------------------
--------Attention le script proposé impose une moyenne par défaut à -1 / le nombre de notes initial est bien à 0 -----
CREATE TABLE Serie(
    SID serial,
    nom varchar(25) NOT NULL,
    plateforme varchar(50) NOT NULL,
    noteMoyenne float DEFAULT -1,
    NbNotes integer DEFAULT 0,
    CONSTRAINT PK_Serie PRIMARY KEY (SID),
    CONSTRAINT CK_UnicitéNomSerie UNIQUE (nom),
	CONSTRAINT CK_UnicitéPFSerie UNIQUE (plateforme)
);

-------création table Personne --------------------------------------------------------------------------------
-------unicité du pseudo, mais aucune demandes sur l unicité nom et/ou prénom   -------------------------------
------>on laisse la possibilité d'homonymes      --------------------------------------------------------------
-------On impose la saisie des nom, prénom et pseudo  ---------------------------------------------------------
CREATE TABLE Personne(
    PID serial,
    nom varchar(25) NOT NULL,
    prenom varchar(25) NOT NULL,
    pseudo varchar(25) NOT NULL,
    CONSTRAINT PK_Personne PRIMARY KEY (PID),
   CONSTRAINT CK_UnicitéPseudo UNIQUE (pseudo)
);

-------création table Abonnes -----------------------------------------------------------------------------------
-------Une personne peut être abonnée ou non à une plate-forme---------------------------------------------------
-------Aucune spécification concernant la possibilité d'être abonné à plusieurs plates-formes--------------------
-------> On a choisi de laisser cette possibilité ouverte--------------------------------------------------------
-------La suppression d'une personne  doit entraîner la suppression de tous ses abonnement --------     ---------
CREATE TABLE Abonnes(
    AID serial,
    PID integer NOT NULL,
    plateforme varchar(50) NOT NULL,
    CONSTRAINT PK_Serial PRIMARY KEY (AID),
    CONSTRAINT FK_abonnes FOREIGN KEY (PID) REFERENCES Personne(PID) ON DELETE CASCADE
);

------création table Evaluation ----------------------------------------------------------------------------------
------Pas d'obligation d être abonné pour noter une série --------------------------------------------------------
------On comprend qu une personne ne peut noter qu'une seule fois une série donnée -------------------------------
------La suppression d'une personne entraîne la suppression de toutes ses évaluations-----------------------------
------Aucune spécification concernant sur la suppression d'une série ---------------------------------------------
------> Pas d'action / passera à null si le cas doit se présenter ------------------------------------------------
------Contrainte : chaque note quand saisie doit être entre 0 inclus et 5 inclus-----------------------------------
CREATE TABLE Evaluation(
    EID serial,
    PID integer NOT NULL,
    SID integer NOT NULL,
    note integer default 5 ,
    CONSTRAINT PK_Eval PRIMARY KEY (EID),
    CONSTRAINT FK_Personne FOREIGN KEY (PID) REFERENCES Personne (PID) ON DELETE CASCADE,
    CONSTRAINT FK_Serie FOREIGN KEY (SID) REFERENCES Serie (SID),
    CONSTRAINT CK_unicitéEvalSeriePersonne UNIQUE (PID,SID),  
    CONSTRAINT CK_note CHECK (note >=0 and note <=5)
    );
  

---------------------------------------------------------------------------------------------------------------------------
--------- TRIGGER ---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------

-----Trigger mise à jour le nombre de notes suite à évaluation d'une série et sa note moyenne -----------------------------
-----Principe général NbNotes = OLD.NbNotes + 1 / prendre en compte le cas initial où la moyenne est à -1 -----------------
create or replace  Function  FonctionNotationSerie() returns trigger as
'DECLARE
   NbNotesSerie Serie.NbNotes %TYPE;
   NoteMoySerie Serie.noteMoyenne %TYPE;
   BEGIN
        SELECT INTO NbNotesSerie,NoteMoySerie NbNotes,noteMoyenne FROM Serie WHERE (SID=NEW.SID);
        IF NbNotesSerie=0 THEN
            UPDATE Serie SET NbNotes=1,NoteMoyenne=NEW.note WHERE SID=NEW.SID;
        ELSE
            UPDATE Serie SET NbNotes = NbNotesSerie + 1  WHERE SID=NEW.SID;
            UPDATE Serie SET NoteMoyenne =(((NoteMoySerie*NbNotesSerie)+NEW.note)/NbNotes) WHERE SID=NEW.SID;
        END IF;
   return NEW;
   END;'
LANGUAGE 'plpgsql';

------Définition des conditions de déclenchement trigger -------------------------------------------------
------Déclenchement lors de l'ajout et/ou de l'update-----------------------------------------------------
------Points non couverts  : mise à jour du nombre de notes et moyennes suite suppression d'une évaluation
CREATE TRIGGER MaJNotes_Moyennes AFTER INSERT OR UPDATE ON Evaluation
FOR EACH ROW
EXECUTE procedure FonctionNotationSerie() ;  


---------------------------------------------------------------------------------------------------------------------------
----------- SCRIPT D'INSERTION DES NUPLETS ------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------

INSERT INTO Serie(nom,plateforme) VALUES 
('Squid Game','Netflix'),
('Validé','Canal +'),
('Germinal','Salto'),
('Game of Thrones','OCS');

INSERT INTO Personne(nom,prenom,pseudo) VALUES 
('Gamotte','Albert','AlGam'),
('Zarela','Maude','mozza'),
('Computing','Claude','cloud');

INSERT INTO Evaluation (PID,SID,note) VALUES 
(1,1,4),(1,2,4),(1,3,3),
(2,1,0),(2,2,3),
(3,1,2);

INSERT INTO Abonnes(PID,plateforme) VALUES (1,'Netflix'),(2,'Canal +');

---Série de tests pour vérifier l'application des différentes contraintes 
---Supprimer le symbole '-' pour exécuter les commandes

--test unicité pseudo
--INSERT INTO Personne(nom,prenom,pseudo) VALUES ('ORANGE','Mecanique','AlGam');

---test non unicité nom et prénom
---INSERT INTO Personne(nom,prenom,pseudo) VALUES ('Gamotte','Albert','AlGambis');

---test note comprise entre 0 inclus et 5 inclus
---INSERT INTO evaluation (PID,SID,note) VALUES (3,1,6);


---test unicité du couple Serie(nom,plateforme) / non demandé
----INSERT INTO Serie(nom,plateforme) VALUES ('Squid Game','Canal +');

---test une personne peut avoir plusieurs abonnements sur la même PF / non demandé
----INSERT INTO abonnes(PID,plateforme) VALUES (1,'Netflix');

---test suppression en cascade Evaluation et Abonnes si suppression d'une personne
---DELETE FROM Personne where PID=2;

-- test fonctionnement trigger 
---de facto en suivant l'évolution des notes lors de l'insertion pas à pas des évaluations


-------------------------------------------------------------------------------------------------------
--------- REQUÊTES DINTERROGATION EN SQL --------------------------------------------------------------
----------LES VERSIONS EN ALGEBRE RELATIONNEL SONT POSITIONNEES A LA SUITE DE CETTE PARTIE ------------

------ ÉNONCÉ A ---------------------------------------------------------------------------------------
------ Quelles plateformes n ont pas d abonnés ? -------------------------------------------------------
SELECT DISTINCT(plateforme)
FROM Serie
WHERE Plateforme NOT IN (SELECT plateforme FROM Abonnes);


------ ÉNONCÉ B ----------------------------------------------------------------------------------------   
------ Quelles personnes (en donnant leur pseudo) ont évalués une série --------------------------------
------ de Netflix ou une série de Canal+ ? -------------------------------------------------------------

------ requête sans l'UNION avec un OR (il s'agit d'un 'ou' inclusif) 
SELECT DISTINCT pseudo 
FROM Personne as p, Evaluation as e, Serie as s
WHERE p.pid=e.pid
AND e.sid=s.sid
AND (s.plateforme='Netflix' OR s.plateforme='Canal +');


------ requête avec l'opérateur UNION
SELECT DISTINCT pseudo  
FROM Personne as p, Evaluation as e, Serie as s
    WHERE p.pid=e.pid
    AND e.sid=s.sid
    AND s.plateforme='Netflix'
 UNION
SELECT DISTINCT pseudo FROM Personne as p, Evaluation as e, Serie as s
    WHERE p.pid=e.pid
    AND e.sid=s.sid
    AND s.plateforme='Canal +';



---Pour l'évaluation du temps d'exécution on se base sur le 'planning time' donné par EXPLAIN ANALYSE-----------
---En effet le temps réel d'éxécution s'est révélé très variable sur le PC utilisé -----------------------------
---et celui sur la plateforme en ligne trop court pour être véritablement discriminant ------------------------

------ >>>> Le TEMPS D'EXÉCUTION est plus élevé dans la requête avec l'UNION
-- (0.222ms pour la requête sans union et 0.626ms pour la requête avec union)


------ ÉNONCÉ C -----------------------------------------------------------------------------------------------
------Quelles personnes (en donnant son pseudo) a évalué une série de -----------------------------------------
------Netflix et une série de Canal+ ? ------------------------------------------------------------------------

------requête sans lintersect forme 1--------------------------------------------------------------------------
SELECT DISTINCT pseudo 
FROM Personne as p, Evaluation as e1,
Evaluation as e2,Serie as s1, Serie as s2
    WHERE p.pid=e1.pid
    AND p.pid=e2.sid
    AND e1.sid=s1.sid
    AND e2.sid=s2.sid
    AND (s1.plateforme='Netflix' or s1.plateforme='Canal +') 
    AND (s2.plateforme='Netflix' or s2.plateforme='Canal +')
    AND s1.plateforme != s2.plateforme;


------requête sans l intersect forme 2 basée sur le principe : A union B = A-(A-B)
CREATE VIEW A as
    SELECT DISTINCT pseudo FROM Personne as p1, Evaluation as e1
    WHERE p1.pid=e1.pid
    AND EXISTS (SELECT * FROM Serie as s1
                 WHERE s1.sid = e1.sid
                   AND s1.plateforme='Netflix');
CREATE VIEW B as
    SELECT DISTINCT pseudo FROM Personne as p2, Evaluation as e2
    WHERE p2.pid=e2.pid
    AND EXISTS (SELECT * FROM Serie as s2
             WHERE s2.sid = e2.sid
               AND s2.plateforme='Canal +');
--view A-B
CREATE VIEW AminusB as
    SELECT pseudo FROM A 
WHERE pseudo NOT IN (SELECT  pseudo FROM B);
--view A=A-(A-B) 
SELECT pseudo FROM A 
WHERE pseudo NOT IN (SELECT  pseudo FROM AminusB) ;

------ requête avec lintersect
SELECT DISTINCT pseudo FROM Personne as p1, Evaluation as e1, Serie as s1
    WHERE p1.pid=e1.pid
    AND e1.sid=s1.sid
    AND s1.plateforme='Netflix'
INTERSECT
SELECT DISTINCT pseudo FROM Personne as p2, Evaluation as e2, Serie as s2
    WHERE p2.pid=e2.pid
    AND e2.sid=s2.sid
    AND s2.plateforme='Canal +';

------ >>>> Le TEMPS D'EXÉCUTION prévisionnel est plus élevé dans la requête sans l'INTERSECT
------1.328ms pour la requête sans intersect forme 1 et 0.787ms pour la requête avec intersect)
------La requête sans intersect forme 2 (A-(A-B)) s'est averée un plus rapide que la forme 2 (1,121 ms)


------ ÉNONCÉ D ---------------------------------------------------------------------------------------------
------ Quelles séries (en donnant leur nom) ont été évaluées par au moins 2 personnes ? ---------------------

 --------1iere forme sans group by et sans exists
SELECT DISTINCT s.nom 
FROM Serie as s, Evaluation as e1, Evaluation as e2
WHERE s.sid=e1.sid
AND s.sid=e2.sid
AND e1.pid != e2.pid;

 --------2ieme forme sans group by mais avec exits
SELECT DISTINCT s.nom 
FROM Serie as s, Evaluation as e1
WHERE s.sid=e1.sid
AND EXISTS (SELECT * FROM Evaluation as e2
          WHERE e2.sid=s.sid
          AND e2.pid != e1.pid);

 -------- 3ieme forme avec group by mais sans exists
 -------- hypothèse centrale : une personne ne peut noter quune seule fois chaque série 
SELECT s.nom FROM Serie as s, Evaluation as e
WHERE s.sid=e.sid
GROUP BY  s.nom
HAVING COUNT (e.EID) >=2;

-- On se base sur le temps prévisionnel fourni par la requête EXPLAIN ANALYSE sur PC 
------ >>>> Le TEMPS D'EXÉCUTION est le plus élevé dans la requête 'sans group by et sans exists',
------ >>>> Le temps le moins élevé est pour la requête 'avec GROUP BY et sans EXITS'
--------- 0.344ms pour la requête sans group by et sans exists, 
--------- 0.279ms pour la requête sans group by mais avec exits 
----------0.219ms pour la requête avec group by mais sans exists


------ ÉNONCÉ E -----------------------------------------------------------------------------------------------------
------ Quelles séries (en donnant leur nom) ont été évaluées par toutes les personnes  ------------------------------
------  de la base de données ? -------------------------------------------------------------------------------------

------ requête sans GROUP BY 1iere version
SELECT DISTINCT nom 
  FROM serie 
  WHERE nom NOT IN (
SELECT s.nom
FROM serie s
CROSS JOIN Personne p
LEFT JOIN evaluation e
ON (e.PID=p.PID AND e.SID=s.SID)
WHERE e.EID IS NULL);

------ requête sans GROUP BY 2ieme version avec la division 
SELECT s.nom FROM Serie as s
WHERE NOT EXISTS (SELECT * FROM Personne as p
              	   		WHERE NOT EXISTS (SELECT * FROM Evaluation as e
                                  				WHERE e.pid=p.pid
                                  				AND  e.sid=s.sid));

------ requête avec GROUP BY 
SELECT s.nom
  FROM evaluation e
  LEFT JOIN serie s ON s.SID = e.SID
  GROUP BY s.nom
  HAVING COUNT (DISTINCT e.PID)=
			(SELECT COUNT(DISTINCT PID)
				FROM personne);

-- On se base sur le temps prévisionnel fourni par la requête EXPLAIN ANALYSE sur PC 
------ >>>> Le TEMPS D'EXÉCUTION est le plus élevé dans la  requête 'sans GROUP BY'
-------- 0.293ms pour la requête sans GROUP BY 1iere forme / valeur proche pour la forme avec la division
-------- 0.227ms pour la requête avec GROUP BY


------ ÉNONCÉ F ---------------------------------------------------------------------------------------------------
------ Quelles séries (en donnant leur nom) sont les moins bien notées ? ------------------------------------------
------En ne tenant compte que de celles qui ont au moins une note -------------------------------------------------

------ 1iere interprétation de la requête demandée : les séries dont les notes sont plus basses que toutes les autres
SELECT s.nom FROM Serie as s, Evaluation as e1
WHERE s.sid=e1.sid
AND e1.note is not null
AND e1.note <= ALL (SELECT note FROM  Evaluation WHERE note IS NOT NULL);

------ 2ieme interprétation de la requête  demandée: les séries dont les notes moyennes sont les plus basses
SELECT nom
  FROM serie
  WHERE NbNotes > 0 
  AND noteMoyenne = (SELECT MIN(noteMoyenne)
                   		FROM serie
                 		  WHERE NbNotes > 0);


------ ÉNONCÉ G ----------------------------------------------------------------------------------------------------
------ Quel est le nombre de notes par série en ne tenant compte que -----------------------------------------------
------ des notes données par les abonnés de la plateforme diffusant la série ? -------------------------------------

SELECT s.plateforme, s.nom, COUNT(*) AS nbnotesabonnes
  FROM abonnes a
  INNER JOIN evaluation e ON e.pid = a.pid
  INNER JOIN serie s ON s.sid = e.sid
  WHERE a.plateforme = s.plateforme
  GROUP BY s.plateforme, s.nom;


------ ÉNONCÉ H --------------------------------------------------------------------------------------------
------ Quel est le nombre de notes par série en séparant les notes données ---------------------------------
------ par les abonnés de la plateforme diffusant la série et les notes des personnes ----------------------
------ non abonnées à la plateforme ? ----------------------------------------------------------------------

------1iere approche prenant comme hypothèse qu'une même personne n'a qu'un seul abonnement à une même plate forme-------------
------Principe du compte des notes des abonnés d'une série : seules les notes des abonnés de cette série y sont comptabilisées

SELECT 
  s.plateforme, 
  s.nom,
  SUM(CASE 
    WHEN (a.plateforme = s.plateforme AND eid IS NOT NULL) THEN 1
    ELSE 0
    END) as nbnotesabonnes, 
  SUM(CASE 
    WHEN  eid IS NOT NULL AND a.plateforme IS NULL
		THEN 1
     ELSE 0
     END) AS nbnotesnonabonnes
  FROM serie s
  LEFT JOIN evaluation e ON e.sid = s.sid
  LEFT JOIN abonnes a ON (a.pid = e.pid AND a.plateforme = s.plateforme)
  GROUP BY s.plateforme, s.nom;


-----2ieme approche pour tenir compte du cas où une personne qui a évalué une série d'une plateforme
----peut avoir un 2ieme abonnement à cette plateforme -----------------------------------------------

------> 1iere étape : création d une table avec les évaluations des seuls abonnés des séries concernées 
Create view WWW as
SELECT s.sid,s.nom,s.plateforme,e.eid FROM serie s, evaluation e, abonnes a
		WHERE e.sid = s.sid
		AND a.pid=e.pid 
		AND s.plateforme=a.plateforme
		GROUP BY s.sid,s.plateforme,e.eid;

------> 2ieme étape : rajout des toutes les évaluations yc. celles de personnes non abonnées aux (Serie,PF) concernées
---------------------et on fait le décompte sur la base des eid pour distinguer les cas des abonnés des autres
SELECT  s.nom,s.plateforme,
SUM(CASE WHEN w.eid IS NOT NULL THEN 1
        ELSE 0
    	END) as nbnotesabonnes,
SUM (CASE WHEN w.eid IS NULL THEN 1
        ELSE  0
    	END) as nbnotesnonabonnes
FROM Evaluation e1
JOIN Serie s on e1.sid=s.sid
LEFT OUTER JOIN WWW w ON w.eid=e1.eid
GROUP BY s.nom,s.plateforme;




---------------------------------------------------------------------------------------------------------------------------
--------- REQUÊTES EN ALGÈBRE RELATIONELLE --------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------

------ ÉNONCÉ A ----------------------------------------------------------------------------------------------------
-->  (PROJECTION sur plateforme (Serie)) MOINS (PROJECTION sur plateforme (Abonnes))

 
------ ÉNONCÉ B ----------------------------------------------------------------------------------------------------

------ version sans l union
--A=SELECTION plateforme =('netflix' Or 'canal +') (Serie)
--B=PROJECTION sur pseudo & sid ((Personne) JOIN (Evaluation))
--> PROJECTION sur pseudo((A) JOIN A.sid=B.sid (B))	

------ version avec l union
--A1=SELECTION plateforme = ('netflix') Serie
--B1=PROJECTION sur pseudo & sid ((Personne) Join (Evaluation))
--R1=PROJECTION sur pseudo((A) JOIN A.sid=B.sid (B))

--A2=SELECTION  plateforme =('netflix') (Serie)
--B2=PROJECTION sur (pseudo & sid) ((Personne) JOIN (Evaluation))
--R2=PROJECTION sur pseudo((A) JOIN A.sid=B.sid (B))

--> R1 UNION R2

 
------ ÉNONCÉ C ----------------------------------------------------------------------------------------------------
---on reprend les définitions des R1 et R2 de l'enonce B

---> R1 INTERSECTION R2


------ ÉNONCÉ D ----------------------------------------------------------------------------------------------------

--C = (SELECTION sid-> e2.sid(Evaluation)) JOIN e2.sid=e1.sid & e1.pid != e2.pid (SELECTION sid->e1.sid(Evaluation))
--> PROJECTION sur s.nom ((SELECTION sid-> s.sid(Serie)) JOIN s.sid=e1.sid(C))
 

 
------ ÉNONCÉ E ----------------------------------------------------------------------------------------------------

--A=SELECTION sid-> e.sid(Evaluation) (toutes les séries qui ont été évaluées)
--B=(SELECTION sid-> s.sid(Serie)) CROSS JOIN  (SELECTION pid-> p.pid(Personne)) (toutes les combinaisons de séries et personnes)

--C=PROJECTION sur s.nom (SELECTION 'eid is null' ((B) LEFT JOIN (p.pid=e.pid AND s.SID=e.SID) (A)))

---PROJECTION sur nom (Serie-C)



