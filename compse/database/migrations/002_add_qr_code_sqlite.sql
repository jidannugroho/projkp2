-- Migration: Add QR Code Support to Assets (SQLite)
-- Description: Add qr_token and qr_code_url columns to existing assets table
-- Created at: 2026-05-12
-- This migration is safe and non-destructive - only adds new columns

-- Add QR Code columns to assets table
ALTER TABLE assets
ADD COLUMN qr_token TEXT UNIQUE;

ALTER TABLE assets
ADD COLUMN qr_code_url TEXT;

-- Create index for faster token lookups
CREATE INDEX IF NOT EXISTS idx_assets_qr_token ON assets(qr_token);
