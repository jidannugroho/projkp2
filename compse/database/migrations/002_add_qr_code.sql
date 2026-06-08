-- Migration: Add QR Code Support to Assets
-- Description: Add qr_token and qr_code_url columns to existing assets table
-- Created at: 2026-05-12
-- This migration is safe and non-destructive - only adds new columns

-- Add QR Code columns to assets table (if they don't exist)
ALTER TABLE assets
ADD COLUMN IF NOT EXISTS qr_token TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS qr_code_url TEXT;

-- Create index for faster token lookups
CREATE INDEX IF NOT EXISTS idx_assets_qr_token ON assets(qr_token);

-- Add comments for documentation
COMMENT ON COLUMN assets.qr_token IS 'Unique token for public asset access via QR Code';
COMMENT ON COLUMN assets.qr_code_url IS 'URL path to the generated QR Code image';
