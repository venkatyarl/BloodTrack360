-- ===========================
-- V1__init.sql — BloodTrack360 schema + seed
-- ===========================
-- Scope:
-- - PII/PHI separation (person vs patient)
-- - Donation -> Blood Unit -> Lab results -> Inventory
-- - Facilities, staff, and provenance (who/where)
-- - Current resolved blood profile per patient
-- - Minimal constraints + indexes for MVP
-- - Seed data for all tables

-- Enable crypto-based UUIDs (core Postgres)
create extension if not exists "pgcrypto";

-- ===== Domains (readable constraints) =====
create domain blood_type as varchar(3)
    check (value in ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'));

create domain inventory_state as varchar(16)
    check (value in ('NEW', 'TESTING', 'RELEASED', 'QUARANTINED', 'EXPIRED', 'DISCARDED'));

create domain lab_result_status as varchar(16)
    check (value in ('PENDING', 'PASSED', 'FAILED', 'INDETERMINATE'));

create domain component_type as varchar(8)
    check (value in ('WB', 'RBC', 'PLT', 'FFP', 'CRYO'));

create domain facility_type as varchar(16)
    check (value in ('COLLECTION', 'LAB', 'STORAGE', 'HOSPITAL'));

create domain staff_role as varchar(16)
    check (value in ('PHLEBOTOMIST', 'LAB_TECH', 'SUPERVISOR', 'QA', 'DRIVER'));

-- ===================== Identity & PHI separation ======================

-- PERSON (PII)
create table if not exists person
(
    person_id     uuid primary key     default gen_random_uuid(),
    first_name    varchar(80) not null,
    last_name     varchar(80) not null,
    date_of_birth date        not null,
    email         varchar(255),
    phone         varchar(40),
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    unique (email),
    unique (phone)
);
create index if not exists idx_person_last_name on person (last_name);
create index if not exists idx_person_date_of_birth on person (date_of_birth);
create index if not exists idx_person_phone on person (phone);

-- PATIENT (clinical role) – links to person
create table if not exists patient
(
    patient_id uuid primary key     default gen_random_uuid(),
    person_id  uuid        not null references person (person_id) on delete cascade,
    mrn        varchar(64) not null,
    active     boolean     not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (mrn),
    unique (person_id)
);
create index if not exists idx_patient_person_id on patient (person_id);
create index if not exists idx_patient_mrn on patient (mrn);

-- Current resolved blood profile for a patient (derived from lab history)
create table if not exists patient_blood_profile
(
    patient_id    uuid primary key references patient (patient_id) on delete cascade,
    blood_type    blood_type  not null,
    antigen_notes varchar(255),         -- e.g., "C-, E-, K-"
    source        varchar(40) not null, -- 'serology', 'molecular', 'historical'
    verified_at   timestamptz not null default now()
);
create index if not exists idx_blood_profile_verified_at on patient_blood_profile (verified_at);

-- =================== Organization & Staff (provenance) =================

-- FACILITY (site metadata)
create table if not exists facility
(
    facility_id   uuid primary key       default gen_random_uuid(),
    facility_code varchar(32)   not null, -- short site code
    name          varchar(120)  not null,
    type          facility_type not null, -- COLLECTION/LAB/STORAGE/HOSPITAL
    phone         varchar(40),
    email         varchar(120),
    address_line1 varchar(120),
    address_line2 varchar(120),
    city          varchar(80),
    state         varchar(40),
    postal_code   varchar(20),
    country       varchar(40)            default 'USA',
    created_at    timestamptz   not null default now(),
    updated_at    timestamptz   not null default now(),
    unique (facility_code)
);
create index if not exists idx_facility_code on facility (facility_code);
create index if not exists idx_facility_type on facility (type);
create index if not exists idx_facility_city on facility (city);
create index if not exists idx_facility_postal_code on facility (postal_code);

-- STAFF (ties to PERSON)
create table if not exists staff
(
    staff_id    uuid primary key     default gen_random_uuid(),
    person_id   uuid        not null references person (person_id) on delete cascade,
    employee_id varchar(64) not null,
    active      boolean     not null default true,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    unique (person_id),
    unique (employee_id)
);
create index if not exists idx_staff_person_id on staff (person_id);
create index if not exists idx_staff_employee_id on staff (employee_id);

-- STAFF ASSIGNMENT (who works where and as what)
create table if not exists staff_assignment
(
    staff_id      uuid        not null references staff (staff_id) on delete cascade,
    facility_id   uuid        not null references facility (facility_id) on delete cascade,
    role          staff_role  not null,
    active        boolean     not null default true,
    assigned_at   timestamptz not null default now(),
    unassigned_at timestamptz,
    primary key (staff_id, facility_id, role)
);
create index if not exists idx_staff_assignment_staff on staff_assignment (staff_id);
create index if not exists idx_staff_assignment_facility on staff_assignment (facility_id);

-- ============================== Donation ==============================

-- DONOR (role) – also ties to person
create table if not exists donor
(
    donor_id     uuid primary key     default gen_random_uuid(),
    person_id    uuid        not null references person (person_id) on delete cascade,
    donor_number varchar(64) not null,
    active       boolean     not null default true,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    unique (donor_number),
    unique (person_id)
);
create index if not exists idx_donor_person_id on donor (person_id);
create index if not exists idx_donor_number on donor (donor_number);

-- DONATION EVENT (collection) + provenance
create table if not exists donation
(
    donation_id            uuid primary key     default gen_random_uuid(),
    donor_id               uuid        not null references donor (donor_id) on delete cascade,
    collection_time        timestamptz not null,
    site_code              varchar(32), -- free text if needed in addition to facility
    collection_facility_id uuid references facility (facility_id),
    collected_by_staff_id  uuid references staff (staff_id),
    notes                  varchar(255),
    created_at             timestamptz not null default now()
);
create index if not exists idx_donation_donor_id on donation (donor_id);
create index if not exists idx_donation_facility on donation (collection_facility_id);
create index if not exists idx_donation_collector on donation (collected_by_staff_id);
create index if not exists idx_donation_time on donation (collection_time);

-- BLOOD UNIT (component derived from a donation)
create table if not exists blood_unit
(
    blood_unit_id    uuid primary key         default gen_random_uuid(),
    donation_id      uuid            not null references donation (donation_id) on delete cascade,
    component        component_type  not null, -- e.g., RBC
    unit_code        varchar(64)     not null, -- label/barcode identifier
    expiration_time  timestamptz,
    inventory_status inventory_state not null default 'NEW',
    created_at       timestamptz     not null default now(),
    updated_at       timestamptz     not null default now(),
    unique (unit_code)
);
create index if not exists idx_blood_unit_donation_id on blood_unit (donation_id);
create index if not exists idx_blood_unit_status on blood_unit (inventory_status);

-- ============================== Lab results ===========================

-- ABO/Rh typing result for a unit + provenance
create table if not exists unit_typing_result
(
    unit_typing_result_id uuid primary key           default gen_random_uuid(),
    blood_unit_id         uuid              not null references blood_unit (blood_unit_id) on delete cascade,
    blood_type            blood_type        not null,
    method                varchar(40)       not null, -- 'serology_forward','serology_reverse','molecular'
    status                lab_result_status not null default 'PENDING',
    tested_at             timestamptz       not null default now(),
    lab_facility_id       uuid references facility (facility_id),
    tested_by_staff_id    uuid references staff (staff_id),
    notes                 varchar(255)
);
create index if not exists idx_unit_typing_unit on unit_typing_result (blood_unit_id);
create index if not exists idx_typing_lab_facility on unit_typing_result (lab_facility_id);
create index if not exists idx_typing_tested_by on unit_typing_result (tested_by_staff_id);

-- Infectious disease screening result per test code + provenance
create table if not exists unit_screening_result
(
    unit_screening_result_id uuid primary key           default gen_random_uuid(),
    blood_unit_id            uuid              not null references blood_unit (blood_unit_id) on delete cascade,
    test_code                varchar(32)       not null, -- e.g., 'HIV-1/2 Ab/Ag','HBsAg'
    status                   lab_result_status not null default 'PENDING',
    value                    varchar(64),                -- optional numeric/qual value
    tested_at                timestamptz       not null default now(),
    lab_facility_id          uuid references facility (facility_id),
    tested_by_staff_id       uuid references staff (staff_id),
    notes                    varchar(255),
    unique (blood_unit_id, test_code)
);
create index if not exists idx_unit_screening_unit on unit_screening_result (blood_unit_id);
create index if not exists idx_screening_lab_facility on unit_screening_result (lab_facility_id);
create index if not exists idx_screening_tested_by on unit_screening_result (tested_by_staff_id);

-- ============================== Inventory =============================

-- Inventory timeline (state machine events) + actor
create table if not exists inventory_event
(
    inventory_event_id uuid primary key         default gen_random_uuid(),
    blood_unit_id      uuid            not null references blood_unit (blood_unit_id) on delete cascade,
    from_status        inventory_state,
    to_status          inventory_state not null,
    reason             varchar(64)     not null, -- 'LAB_PASSED','LAB_FAILED','EXPIRED','MANUAL_HOLD', etc.
    actor_staff_id     uuid references staff (staff_id),
    created_at         timestamptz     not null default now()
);
create index if not exists idx_inv_event_unit on inventory_event (blood_unit_id);
create index if not exists idx_inv_event_actor on inventory_event (actor_staff_id);

-- =====================================================================
-- ============================ SEED DATA ===============================
-- =====================================================================

-- Facilities
insert into facility (facility_code, name, type, phone, city, state, postal_code)
values ('COLL-001', 'Miramar Collection Center', 'COLLECTION', '954-555-1001', 'Miramar', 'FL', '33027'),
       ('LAB-001', 'Central Serology Lab', 'LAB', '954-555-2001', 'Miramar', 'FL', '33027'),
       ('STOR-001', 'Primary Storage', 'STORAGE', '954-555-3001', 'Miramar', 'FL', '33027'),
       ('HOSP-001', 'Partner Hospital', 'HOSPITAL', '954-555-4001', 'Miramar', 'FL', '33027')
on conflict (facility_code) do nothing;

-- People (some patients, some staff, some donors)
insert into person (first_name, last_name, date_of_birth, email, phone)
values ('Jane', 'Doe', '1990-03-12', 'jane@example.com', '555-0100'),
       ('John', 'Smith', '1985-07-22', 'john.smith@example.com', '555-0200'),
       ('Alice', 'Nguyen', '1979-11-02', 'alice.nguyen@example.com', '555-0300'),
       ('Carlos', 'Lopez', '1993-05-18', 'carlos.lopez@example.com', '555-0400'),
       ('Priya', 'Patel', '1988-09-09', 'priya.patel@example.com', '555-0500'),
       ('Sam', 'Taylor', '1992-01-15', 'sam.taylor@example.com', '555-0600') -- donor-only
on conflict (email) do nothing;

-- Staff (ties to person)
insert into staff (person_id, employee_id)
select p.person_id, e.emp_id
from (values ('john.smith@example.com', 'EMP-1001'),
             ('alice.nguyen@example.com', 'EMP-1002'),
             ('carlos.lopez@example.com', 'EMP-1003')) as e(email, emp_id)
         join person p on p.email = e.email
on conflict (employee_id) do nothing;

-- Staff assignments to facilities
insert into staff_assignment (staff_id, facility_id, role)
select s.staff_id, f.facility_id, 'PHLEBOTOMIST'
from staff s
         join person p on p.person_id = s.person_id and p.email = 'john.smith@example.com'
         join facility f on f.facility_code = 'COLL-001'
on conflict do nothing;

insert into staff_assignment (staff_id, facility_id, role)
select s.staff_id, f.facility_id, 'LAB_TECH'
from staff s
         join person p on p.person_id = s.person_id and p.email = 'alice.nguyen@example.com'
         join facility f on f.facility_code = 'LAB-001'
on conflict do nothing;

insert into staff_assignment (staff_id, facility_id, role)
select s.staff_id, f.facility_id, 'SUPERVISOR'
from staff s
         join person p on p.person_id = s.person_id and p.email = 'carlos.lopez@example.com'
         join facility f on f.facility_code = 'LAB-001'
on conflict do nothing;

-- Patients
insert into patient (person_id, mrn)
select p.person_id, v.mrn
from (values ('jane@example.com', 'MRN-0001'),
             ('priya.patel@example.com', 'MRN-0002')) as v(email, mrn)
         join person p on p.email = v.email
on conflict (mrn) do nothing;

-- Patient blood profile (resolved, for demo)
insert into patient_blood_profile (patient_id, blood_type, antigen_notes, source)
select pt.patient_id, v.blood_type, v.antigen_notes, v.source
from (values ('MRN-0001', 'A+', 'K-', 'historical'),
             ('MRN-0002', 'O-', 'C-,E-', 'serology')) as v(mrn, blood_type, antigen_notes, source)
         join patient pt on pt.mrn = v.mrn
on conflict (patient_id) do nothing;

-- Donors
insert into donor (person_id, donor_number)
select p.person_id, v.donor_number
from (values ('sam.taylor@example.com', 'DNR-5001'),
             ('john.smith@example.com', 'DNR-5002') -- staff can also be donors in some systems
     ) as v(email, donor_number)
         join person p on p.email = v.email
on conflict (donor_number) do nothing;

-- Donations (with provenance)
insert into donation (donor_id, collection_time, site_code, collection_facility_id, collected_by_staff_id, notes)
select d.donor_id, now() - interval '1 day', 'MIR-01', f.facility_id, s.staff_id, 'Whole blood'
from donor d
         join person pd on pd.person_id = d.person_id and pd.email = 'sam.taylor@example.com'
         left join facility f on f.facility_code = 'COLL-001'
         left join staff s on s.employee_id = 'EMP-1001'
on conflict do nothing;

insert into donation (donor_id, collection_time, site_code, collection_facility_id, collected_by_staff_id, notes)
select d.donor_id, now() - interval '2 days', 'MIR-02', f.facility_id, s.staff_id, 'Whole blood'
from donor d
         join person pd on pd.person_id = d.person_id and pd.email = 'john.smith@example.com'
         left join facility f on f.facility_code = 'COLL-001'
         left join staff s on s.employee_id = 'EMP-1001'
on conflict do nothing;

-- Blood units from donations
insert into blood_unit (donation_id, component, unit_code, expiration_time, inventory_status)
select dn.donation_id, 'RBC', 'UNIT-0001', now() + interval '35 days', 'NEW'
from donation dn
         join donor d on d.donor_id = dn.donor_id
         join person pd on pd.person_id = d.person_id and pd.email = 'sam.taylor@example.com'
on conflict (unit_code) do nothing;

insert into blood_unit (donation_id, component, unit_code, expiration_time, inventory_status)
select dn.donation_id, 'RBC', 'UNIT-0002', now() + interval '35 days', 'NEW'
from donation dn
         join donor d on d.donor_id = dn.donor_id
         join person pd on pd.person_id = d.person_id and pd.email = 'john.smith@example.com'
on conflict (unit_code) do nothing;

-- Typing results (flip units into TESTING conceptually)
insert into unit_typing_result (blood_unit_id, blood_type, method, status, lab_facility_id, tested_by_staff_id, notes)
select bu.blood_unit_id, 'O-', 'serology_forward', 'PASSED', f.facility_id, s.staff_id, 'Forward typing OK'
from blood_unit bu
         join donation dn on dn.donation_id = bu.donation_id
         join donor d on d.donor_id = dn.donor_id
         join person pd on pd.person_id = d.person_id and pd.email = 'sam.taylor@example.com'
         left join facility f on f.facility_code = 'LAB-001'
         left join staff s on s.employee_id = 'EMP-1002'
where bu.unit_code = 'UNIT-0001'
on conflict do nothing;

insert into unit_typing_result (blood_unit_id, blood_type, method, status, lab_facility_id, tested_by_staff_id, notes)
select bu.blood_unit_id, 'A+', 'serology_forward', 'PASSED', f.facility_id, s.staff_id, 'Forward typing OK'
from blood_unit bu
         join donation dn on dn.donation_id = bu.donation_id
         join donor d on d.donor_id = dn.donor_id
         join person pd on pd.person_id = d.person_id and pd.email = 'john.smith@example.com'
         left join facility f on f.facility_code = 'LAB-001'
         left join staff s on s.employee_id = 'EMP-1002'
where bu.unit_code = 'UNIT-0002'
on conflict do nothing;

-- Infectious screening results (passing for UNIT-0001, failing for UNIT-0002)
-- UNIT-0001 (all PASSED)
insert into unit_screening_result (blood_unit_id, test_code, status, value, lab_facility_id, tested_by_staff_id, notes)
select bu.blood_unit_id, 'HBsAg', 'PASSED', 'NEG', f.facility_id, s.staff_id, 'Non-reactive'
from blood_unit bu
         left join facility f on f.facility_code = 'LAB-001'
         left join staff s on s.employee_id = 'EMP-1002'
where bu.unit_code = 'UNIT-0001'
on conflict do nothing;

insert into unit_screening_result (blood_unit_id, test_code, status, value, lab_facility_id, tested_by_staff_id, notes)
select bu.blood_unit_id, 'HIV-1/2 Ab/Ag', 'PASSED', 'NEG', f.facility_id, s.staff_id, 'Non-reactive'
from blood_unit bu
         left join facility f on f.facility_code = 'LAB-001'
         left join staff s on s.employee_id = 'EMP-1002'
where bu.unit_code = 'UNIT-0001'
on conflict do nothing;

-- UNIT-0002 (one FAILED)
insert into unit_screening_result (blood_unit_id, test_code, status, value, lab_facility_id, tested_by_staff_id, notes)
select bu.blood_unit_id, 'HBsAg', 'FAILED', 'REACTIVE', f.facility_id, s.staff_id, 'Reactive on initial screen'
from blood_unit bu
         left join facility f on f.facility_code = 'LAB-001'
         left join staff s on s.employee_id = 'EMP-1002'
where bu.unit_code = 'UNIT-0002'
on conflict do nothing;

insert into unit_screening_result (blood_unit_id, test_code, status, value, lab_facility_id, tested_by_staff_id, notes)
select bu.blood_unit_id, 'HIV-1/2 Ab/Ag', 'PASSED', 'NEG', f.facility_id, s.staff_id, 'Non-reactive'
from blood_unit bu
         left join facility f on f.facility_code = 'LAB-001'
         left join staff s on s.employee_id = 'EMP-1002'
where bu.unit_code = 'UNIT-0002'
on conflict do nothing;

-- Inventory events (manual transitions for demo)
-- UNIT-0001: NEW -> TESTING -> RELEASED
insert into inventory_event (blood_unit_id, from_status, to_status, reason, actor_staff_id)
select bu.blood_unit_id, 'NEW', 'TESTING', 'LAB_STARTED', s.staff_id
from blood_unit bu
         left join staff s on s.employee_id = 'EMP-1002'
where bu.unit_code = 'UNIT-0001'
on conflict do nothing;

update blood_unit
set inventory_status = 'TESTING',
    updated_at       = now()
where unit_code = 'UNIT-0001';

insert into inventory_event (blood_unit_id, from_status, to_status, reason, actor_staff_id)
select bu.blood_unit_id, 'TESTING', 'RELEASED', 'LAB_PASSED', s.staff_id
from blood_unit bu
         left join staff s on s.employee_id = 'EMP-1003'
where bu.unit_code = 'UNIT-0001'
on conflict do nothing;

update blood_unit
set inventory_status = 'RELEASED',
    updated_at       = now()
where unit_code = 'UNIT-0001';

-- UNIT-0002: NEW -> TESTING -> QUARANTINED (due to failed screen)
insert into inventory_event (blood_unit_id, from_status, to_status, reason, actor_staff_id)
select bu.blood_unit_id, 'NEW', 'TESTING', 'LAB_STARTED', s.staff_id
from blood_unit bu
         left join staff s on s.employee_id = 'EMP-1002'
where bu.unit_code = 'UNIT-0002'
on conflict do nothing;

update blood_unit
set inventory_status = 'TESTING',
    updated_at       = now()
where unit_code = 'UNIT-0002';

insert into inventory_event (blood_unit_id, from_status, to_status, reason, actor_staff_id)
select bu.blood_unit_id, 'TESTING', 'QUARANTINED', 'LAB_FAILED', s.staff_id
from blood_unit bu
         left join staff s on s.employee_id = 'EMP-1003'
where bu.unit_code = 'UNIT-0002'
on conflict do nothing;

update blood_unit
set inventory_status = 'QUARANTINED',
    updated_at       = now()
where unit_code = 'UNIT-0002';
