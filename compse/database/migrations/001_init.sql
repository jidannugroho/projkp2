-- Migration: Initial Schema for Asset Management System
-- Description: Migration from Supabase to pure PostgreSQL 16
-- Created at: 2026-04-29

-- Enable UUID extension (built-in in PG 13+, but good practice to ensure)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create Enum Types
CREATE TYPE asset_status AS ENUM ('active', 'maintenance', 'broken', 'inactive');
CREATE TYPE maintenance_status AS ENUM ('scheduled', 'in-progress', 'completed');

-- 2. Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create Tables

-- Users Table (Replacing auth.users)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT CHECK (role IN ('superadmin', 'staff')) NOT NULL DEFAULT 'staff',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Profiles Table
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    display_name TEXT,
    position TEXT,
    department TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Locations Table
CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Assets Table
CREATE TABLE assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    location TEXT NOT NULL,
    room TEXT NOT NULL,
    status asset_status DEFAULT 'active',
    purchase_date DATE,
    purchase_price NUMERIC(15,2) DEFAULT 0,
    current_value NUMERIC(15,2) DEFAULT 0,
    depreciation_rate NUMERIC(5,2) DEFAULT 0,
    last_maintenance DATE,
    next_maintenance DATE,
    assigned_to TEXT,
    serial_number TEXT,
    condition TEXT,
    is_archived BOOLEAN DEFAULT false,
    archive_year INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Maintenance Records Table
CREATE TABLE maintenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    asset_name TEXT,
    type TEXT NOT NULL,
    date DATE NOT NULL,
    status maintenance_status DEFAULT 'scheduled',
    cost NUMERIC(15,2) DEFAULT 0,
    technician TEXT,
    notes TEXT,
    user_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Custom Floors Table
CREATE TABLE custom_floors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Custom Rooms Table
CREATE TABLE custom_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    name TEXT NOT NULL,
    floor_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Custom Categories Table
CREATE TABLE custom_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    name TEXT NOT NULL,
    icon TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Custom Assignments Table
CREATE TABLE custom_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    label TEXT NOT NULL,
    department TEXT,
    position TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit Logs Table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    entity_type TEXT,
    entity_id TEXT,
    details JSONB,
    ip_address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Asset Notifications Table
CREATE TABLE asset_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    asset_id UUID REFERENCES assets(id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'info',
    title TEXT NOT NULL,
    message TEXT,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Backup Logs Table
CREATE TABLE backup_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    type TEXT NOT NULL DEFAULT 'backup',
    file_name TEXT,
    status TEXT,
    record_count INTEGER,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reports Table
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    name TEXT NOT NULL,
    type TEXT,
    content JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Todos Table
CREATE TABLE todos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    time TEXT DEFAULT '00:00',
    completed BOOLEAN DEFAULT false,
    color TEXT DEFAULT 'primary' CHECK (color IN ('primary', 'status-maintenance', 'destructive')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_locations_updated_at BEFORE UPDATE ON locations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_assets_updated_at BEFORE UPDATE ON assets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_maintenance_records_updated_at BEFORE UPDATE ON maintenance_records FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_todos_updated_at BEFORE UPDATE ON todos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 5. Create Relevant Indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_profiles_user_id ON profiles(user_id);
CREATE INDEX idx_assets_user_id ON assets(user_id);
CREATE INDEX idx_assets_status ON assets(status);
CREATE INDEX idx_assets_category ON assets(category);
CREATE INDEX idx_maintenance_asset_id ON maintenance_records(asset_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX idx_notifications_user_unread ON asset_notifications(user_id, is_read);
CREATE INDEX idx_custom_rooms_floor ON custom_rooms(floor_name);
CREATE INDEX idx_todos_user_id ON todos(user_id);
CREATE INDEX idx_todos_created_at ON todos(created_at DESC);

-- 6. Default Superadmin Seed Data
-- Note: Password hash should be generated using a library like bcrypt or argon2 in the application layer.
-- For this seed, we use a placeholder that would be recognized by the app.
INSERT INTO users (email, password_hash, role, is_active)
VALUES (
    'admin@sekolah.com',
    '$2a$12$4KZ1AdYGEh9A96K/1FrD9u7JRGQCL/JmE0Hi6c08qXp/5skNfvMji', -- Placeholder bcrypt hash
    'superadmin',
    true
) RETURNING id;

-- Insert corresponding profile for the admin (using the ID from previous insert)
-- In a real migration script with variables, you'd capture the ID. 
-- For a standalone SQL file, we can use a subquery.
INSERT INTO profiles (user_id, display_name, position, department)
SELECT id, 'Super Admin', 'System Administrator', 'IT Department'
FROM users WHERE email = 'admin@sekolah.com';
