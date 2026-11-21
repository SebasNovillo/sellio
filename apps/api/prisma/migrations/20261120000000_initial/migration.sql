-- Sellio initial migration: generated locally; not applied.
BEGIN;

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "user_role" AS ENUM ('CUSTOMER', 'MANAGER', 'ADMIN');

-- CreateEnum
CREATE TYPE "product_status" AS ENUM ('DRAFT', 'ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "category_status" AS ENUM ('DRAFT', 'ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "variant_status" AS ENUM ('ACTIVE', 'INACTIVE');

-- CreateEnum
CREATE TYPE "cart_status" AS ENUM ('ACTIVE', 'CONVERTED', 'ABANDONED');

-- CreateEnum
CREATE TYPE "checkout_attempt_status" AS ENUM ('RECEIVED', 'PROCESSING', 'AWAITING_PAYMENT', 'COMPLETED', 'FAILED', 'CANCELLED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "reservation_status" AS ENUM ('ACTIVE', 'CONSUMED', 'RELEASED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "inventory_movement_reason" AS ENUM ('RECEIPT', 'ADJUSTMENT', 'SALE', 'RETURN', 'CORRECTION');

-- CreateEnum
CREATE TYPE "order_status" AS ENUM ('PENDING_PAYMENT', 'PAID', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'PAYMENT_FAILED');

-- CreateEnum
CREATE TYPE "payment_status" AS ENUM ('PENDING', 'REQUIRES_ACTION', 'SUCCEEDED', 'FAILED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "payment_provider" AS ENUM ('STRIPE');

-- CreateEnum
CREATE TYPE "payment_event_status" AS ENUM ('RECEIVED', 'PROCESSED', 'FAILED');

-- CreateEnum
CREATE TYPE "reconciliation_status" AS ENUM ('NONE', 'REQUIRED', 'RESOLVED');

-- CreateTable
CREATE TABLE "user" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "auth_id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "first_name" TEXT,
    "last_name" TEXT,
    "role" "user_role" NOT NULL DEFAULT 'CUSTOMER',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "user_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "address" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "recipient_name" TEXT NOT NULL,
    "line1" TEXT NOT NULL,
    "line2" TEXT,
    "city" TEXT NOT NULL,
    "region" TEXT,
    "postal_code" TEXT NOT NULL,
    "country_code" CHAR(2) NOT NULL,
    "phone" TEXT,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "address_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "brand" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "brand_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "category" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "parent_id" UUID,
    "status" "category_status" NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "category_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "description" TEXT,
    "status" "product_status" NOT NULL,
    "brand_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "product_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_category" (
    "product_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_category_pkey" PRIMARY KEY ("product_id","category_id")
);

-- CreateTable
CREATE TABLE "product_image" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "product_id" UUID NOT NULL,
    "storage_path" TEXT NOT NULL,
    "alt_text" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "product_image_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_option" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "product_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "product_option_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_option_value" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "option_id" UUID NOT NULL,
    "value" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "product_option_value_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_variant" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "product_id" UUID NOT NULL,
    "sku" TEXT NOT NULL,
    "price" DECIMAL(12,2) NOT NULL,
    "compare_at_price" DECIMAL(12,2),
    "currency" CHAR(3) NOT NULL,
    "status" "variant_status" NOT NULL,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "option_signature" VARCHAR(1024) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "product_variant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "variant_option_value" (
    "variant_id" UUID NOT NULL,
    "option_value_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "variant_option_value_pkey" PRIMARY KEY ("variant_id","option_value_id")
);

-- CreateTable
CREATE TABLE "inventory_item" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "variant_id" UUID NOT NULL,
    "quantity_on_hand" INTEGER NOT NULL DEFAULT 0,
    "quantity_reserved" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "inventory_item_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inventory_reservation" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "inventory_item_id" UUID NOT NULL,
    "checkout_attempt_id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "quantity" INTEGER NOT NULL,
    "status" "reservation_status" NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "inventory_reservation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inventory_movement" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "inventory_item_id" UUID NOT NULL,
    "quantity_delta" INTEGER NOT NULL,
    "reason" "inventory_movement_reason" NOT NULL,
    "order_id" UUID,
    "actor_user_id" UUID,
    "reservation_id" UUID,
    "note" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "inventory_movement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cart" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "guest_token_hash" TEXT,
    "status" "cart_status" NOT NULL,
    "revision" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cart_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cart_item" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "cart_id" UUID NOT NULL,
    "variant_id" UUID NOT NULL,
    "quantity" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cart_item_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "checkout_attempt" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "cart_id" UUID NOT NULL,
    "cart_revision" INTEGER NOT NULL,
    "idempotency_key" VARCHAR(128) NOT NULL,
    "request_fingerprint" CHAR(64) NOT NULL,
    "fingerprint_version" SMALLINT NOT NULL,
    "request_snapshot" JSONB NOT NULL,
    "status" "checkout_attempt_status" NOT NULL,
    "order_id" UUID,
    "processing_token" UUID,
    "processing_lease_expires_at" TIMESTAMPTZ(6),
    "retry_count" INTEGER NOT NULL DEFAULT 0,
    "next_retry_at" TIMESTAMPTZ(6),
    "retention_expires_at" TIMESTAMPTZ(6),
    "last_error_code" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "checkout_attempt_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_number" TEXT NOT NULL,
    "user_id" UUID NOT NULL,
    "source_cart_id" UUID NOT NULL,
    "status" "order_status" NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "subtotal" DECIMAL(12,2) NOT NULL,
    "shipping_total" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "tax_total" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "discount_total" DECIMAL(12,2) NOT NULL,
    "grand_total" DECIMAL(12,2) NOT NULL,
    "tax_details_snapshot" JSONB,
    "shipping_method_snapshot" JSONB,
    "accepted_payment_id" UUID,
    "reconciliation_status" "reconciliation_status" NOT NULL DEFAULT 'NONE',
    "reconciliation_reason" TEXT,
    "reconciliation_detected_at" TIMESTAMPTZ(6),
    "reconciliation_resolved_at" TIMESTAMPTZ(6),
    "reconciliation_resolved_by_user_id" UUID,
    "reconciliation_resolution_note" TEXT,
    "paid_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "order_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_item" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL,
    "variant_id" UUID,
    "product_name_snapshot" TEXT NOT NULL,
    "sku_snapshot" TEXT NOT NULL,
    "options_snapshot" JSONB NOT NULL,
    "unit_price" DECIMAL(12,2) NOT NULL,
    "quantity" INTEGER NOT NULL,
    "line_total" DECIMAL(12,2) NOT NULL,
    "tax_total" DECIMAL(12,2),
    "discount_total" DECIMAL(12,2),
    "currency" CHAR(3) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "order_item_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_address" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL,
    "recipient_name" TEXT NOT NULL,
    "line1" TEXT NOT NULL,
    "line2" TEXT,
    "city" TEXT NOT NULL,
    "region" TEXT,
    "postal_code" TEXT NOT NULL,
    "country_code" CHAR(2) NOT NULL,
    "phone" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "order_address_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL,
    "provider" "payment_provider" NOT NULL,
    "provider_payment_id" TEXT,
    "provider_checkout_session_id" TEXT,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "status" "payment_status" NOT NULL,
    "reconciliation_status" "reconciliation_status" NOT NULL DEFAULT 'NONE',
    "reconciliation_reason" TEXT,
    "reconciliation_detected_at" TIMESTAMPTZ(6),
    "reconciliation_resolved_at" TIMESTAMPTZ(6),
    "reconciliation_resolved_by_user_id" UUID,
    "reconciliation_resolution_note" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "payment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_event" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "provider" "payment_provider" NOT NULL,
    "provider_event_id" TEXT NOT NULL,
    "provider_object_id" TEXT,
    "payment_id" UUID,
    "event_type" TEXT NOT NULL,
    "processing_status" "payment_event_status" NOT NULL,
    "received_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processed_at" TIMESTAMPTZ(6),
    "error_code" TEXT,

    CONSTRAINT "payment_event_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "user_auth_id_key" ON "user"("auth_id");

-- CreateIndex
CREATE INDEX "address_user_id_idx" ON "address"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "brand_slug_key" ON "brand"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "category_slug_key" ON "category"("slug");

-- CreateIndex
CREATE INDEX "category_parent_id_idx" ON "category"("parent_id");

-- CreateIndex
CREATE UNIQUE INDEX "product_slug_key" ON "product"("slug");

-- CreateIndex
CREATE INDEX "product_status_created_at_idx" ON "product"("status", "created_at");

-- CreateIndex
CREATE INDEX "product_brand_id_idx" ON "product"("brand_id");

-- CreateIndex
CREATE INDEX "product_category_category_id_product_id_idx" ON "product_category"("category_id", "product_id");

-- CreateIndex
CREATE INDEX "product_image_product_id_position_idx" ON "product_image"("product_id", "position");

-- CreateIndex
CREATE UNIQUE INDEX "product_option_product_id_name_key" ON "product_option"("product_id", "name");

-- CreateIndex
CREATE UNIQUE INDEX "product_option_value_option_id_value_key" ON "product_option_value"("option_id", "value");

-- CreateIndex
CREATE UNIQUE INDEX "product_variant_sku_key" ON "product_variant"("sku");

-- CreateIndex
CREATE INDEX "product_variant_product_id_status_idx" ON "product_variant"("product_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "product_variant_product_id_option_signature_key" ON "product_variant"("product_id", "option_signature");

-- CreateIndex
CREATE INDEX "variant_option_value_option_value_id_idx" ON "variant_option_value"("option_value_id");

-- CreateIndex
CREATE UNIQUE INDEX "inventory_item_variant_id_key" ON "inventory_item"("variant_id");

-- CreateIndex
CREATE INDEX "inventory_reservation_status_expires_at_idx" ON "inventory_reservation"("status", "expires_at");

-- CreateIndex
CREATE INDEX "inventory_reservation_order_id_idx" ON "inventory_reservation"("order_id");

-- CreateIndex
CREATE INDEX "inventory_reservation_inventory_item_id_idx" ON "inventory_reservation"("inventory_item_id");

-- CreateIndex
CREATE UNIQUE INDEX "inventory_reservation_attempt_item_key" ON "inventory_reservation"("checkout_attempt_id", "inventory_item_id");

-- CreateIndex
CREATE INDEX "inventory_movement_item_created_at_idx" ON "inventory_movement"("inventory_item_id", "created_at");

-- CreateIndex
CREATE INDEX "inventory_movement_order_id_idx" ON "inventory_movement"("order_id");

-- CreateIndex
CREATE INDEX "inventory_movement_actor_user_id_idx" ON "inventory_movement"("actor_user_id");

-- CreateIndex
CREATE INDEX "inventory_movement_reservation_id_idx" ON "inventory_movement"("reservation_id");

-- CreateIndex
CREATE INDEX "cart_user_id_idx" ON "cart"("user_id");

-- CreateIndex
CREATE INDEX "cart_item_variant_id_idx" ON "cart_item"("variant_id");

-- CreateIndex
CREATE UNIQUE INDEX "cart_item_cart_id_variant_id_key" ON "cart_item"("cart_id", "variant_id");

-- CreateIndex
CREATE UNIQUE INDEX "checkout_attempt_order_id_key" ON "checkout_attempt"("order_id");

-- CreateIndex
CREATE INDEX "checkout_attempt_status_next_retry_at_idx" ON "checkout_attempt"("status", "next_retry_at");

-- CreateIndex
CREATE INDEX "checkout_attempt_retention_expires_at_idx" ON "checkout_attempt"("retention_expires_at");

-- CreateIndex
CREATE INDEX "checkout_attempt_cart_id_created_at_idx" ON "checkout_attempt"("cart_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "checkout_attempt_user_id_idempotency_key_key" ON "checkout_attempt"("user_id", "idempotency_key");

-- CreateIndex
CREATE UNIQUE INDEX "order_order_number_key" ON "order"("order_number");

-- CreateIndex
CREATE UNIQUE INDEX "order_source_cart_id_key" ON "order"("source_cart_id");

-- CreateIndex
CREATE UNIQUE INDEX "order_accepted_payment_id_key" ON "order"("accepted_payment_id");

-- CreateIndex
CREATE INDEX "order_user_id_created_at_idx" ON "order"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "order_reconciliation_status_updated_at_idx" ON "order"("reconciliation_status", "updated_at");

-- CreateIndex
CREATE INDEX "order_reconciliation_resolver_idx" ON "order"("reconciliation_resolved_by_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "order_accepted_payment_id_id_key" ON "order"("accepted_payment_id", "id");

-- CreateIndex
CREATE INDEX "order_item_order_id_idx" ON "order_item"("order_id");

-- CreateIndex
CREATE INDEX "order_item_variant_id_idx" ON "order_item"("variant_id");

-- CreateIndex
CREATE UNIQUE INDEX "order_address_order_id_key" ON "order_address"("order_id");

-- CreateIndex
CREATE INDEX "payment_order_id_created_at_idx" ON "payment"("order_id", "created_at");

-- CreateIndex
CREATE INDEX "payment_reconciliation_status_updated_at_idx" ON "payment"("reconciliation_status", "updated_at");

-- CreateIndex
CREATE INDEX "payment_reconciliation_resolver_idx" ON "payment"("reconciliation_resolved_by_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "payment_id_order_id_key" ON "payment"("id", "order_id");

-- CreateIndex
CREATE UNIQUE INDEX "payment_provider_payment_id_key" ON "payment"("provider", "provider_payment_id");

-- CreateIndex
CREATE UNIQUE INDEX "payment_provider_checkout_session_id_key" ON "payment"("provider", "provider_checkout_session_id");

-- CreateIndex
CREATE INDEX "payment_event_processing_status_received_at_idx" ON "payment_event"("processing_status", "received_at");

-- CreateIndex
CREATE INDEX "payment_event_payment_id_idx" ON "payment_event"("payment_id");

-- CreateIndex
CREATE UNIQUE INDEX "payment_event_provider_event_id_key" ON "payment_event"("provider", "provider_event_id");

-- AddForeignKey
ALTER TABLE "address" ADD CONSTRAINT "address_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "category" ADD CONSTRAINT "category_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "category"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "product" ADD CONSTRAINT "product_brand_id_fkey" FOREIGN KEY ("brand_id") REFERENCES "brand"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "product_category" ADD CONSTRAINT "product_category_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "product"("id") ON DELETE CASCADE ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "product_category" ADD CONSTRAINT "product_category_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "category"("id") ON DELETE CASCADE ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "product_image" ADD CONSTRAINT "product_image_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "product"("id") ON DELETE CASCADE ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "product_option" ADD CONSTRAINT "product_option_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "product"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "product_option_value" ADD CONSTRAINT "product_option_value_option_id_fkey" FOREIGN KEY ("option_id") REFERENCES "product_option"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "product_variant" ADD CONSTRAINT "product_variant_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "product"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "variant_option_value" ADD CONSTRAINT "variant_option_value_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "product_variant"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "variant_option_value" ADD CONSTRAINT "variant_option_value_option_value_id_fkey" FOREIGN KEY ("option_value_id") REFERENCES "product_option_value"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_item" ADD CONSTRAINT "inventory_item_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "product_variant"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_reservation" ADD CONSTRAINT "inventory_reservation_inventory_item_id_fkey" FOREIGN KEY ("inventory_item_id") REFERENCES "inventory_item"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_reservation" ADD CONSTRAINT "inventory_reservation_checkout_attempt_id_fkey" FOREIGN KEY ("checkout_attempt_id") REFERENCES "checkout_attempt"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_reservation" ADD CONSTRAINT "inventory_reservation_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "order"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_movement" ADD CONSTRAINT "inventory_movement_inventory_item_id_fkey" FOREIGN KEY ("inventory_item_id") REFERENCES "inventory_item"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_movement" ADD CONSTRAINT "inventory_movement_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "order"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_movement" ADD CONSTRAINT "inventory_movement_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "user"("id") ON DELETE SET NULL ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_movement" ADD CONSTRAINT "inventory_movement_reservation_id_fkey" FOREIGN KEY ("reservation_id") REFERENCES "inventory_reservation"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "cart" ADD CONSTRAINT "cart_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "cart_item" ADD CONSTRAINT "cart_item_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "cart"("id") ON DELETE CASCADE ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "cart_item" ADD CONSTRAINT "cart_item_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "product_variant"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "checkout_attempt" ADD CONSTRAINT "checkout_attempt_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "checkout_attempt" ADD CONSTRAINT "checkout_attempt_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "cart"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "checkout_attempt" ADD CONSTRAINT "checkout_attempt_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "order"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "order" ADD CONSTRAINT "order_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "order" ADD CONSTRAINT "order_source_cart_id_fkey" FOREIGN KEY ("source_cart_id") REFERENCES "cart"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "order" ADD CONSTRAINT "order_accepted_payment_id_id_fkey" FOREIGN KEY ("accepted_payment_id", "id") REFERENCES "payment"("id", "order_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "order" ADD CONSTRAINT "order_reconciliation_resolved_by_user_id_fkey" FOREIGN KEY ("reconciliation_resolved_by_user_id") REFERENCES "user"("id") ON DELETE SET NULL ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "order_item" ADD CONSTRAINT "order_item_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "order"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "order_item" ADD CONSTRAINT "order_item_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "product_variant"("id") ON DELETE SET NULL ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "order_address" ADD CONSTRAINT "order_address_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "order"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment" ADD CONSTRAINT "payment_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "order"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment" ADD CONSTRAINT "payment_reconciliation_resolved_by_user_id_fkey" FOREIGN KEY ("reconciliation_resolved_by_user_id") REFERENCES "user"("id") ON DELETE SET NULL ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment_event" ADD CONSTRAINT "payment_event_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "payment"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- Sellio custom integrity: PRISMA_FOUNDATION.md section 6.
CREATE UNIQUE INDEX address_one_default_per_user_key
  ON address (user_id) WHERE is_default;
CREATE UNIQUE INDEX product_image_one_primary_key
  ON product_image (product_id) WHERE is_primary;
CREATE UNIQUE INDEX product_variant_one_default_key
  ON product_variant (product_id) WHERE is_default;
CREATE UNIQUE INDEX cart_one_active_per_user_key
  ON cart (user_id) WHERE status = 'ACTIVE' AND user_id IS NOT NULL;
CREATE UNIQUE INDEX cart_guest_token_hash_key
  ON cart (guest_token_hash) WHERE guest_token_hash IS NOT NULL;
CREATE UNIQUE INDEX checkout_attempt_one_live_per_cart_key
  ON checkout_attempt (cart_id)
  WHERE status IN ('RECEIVED', 'PROCESSING', 'AWAITING_PAYMENT');
CREATE UNIQUE INDEX inventory_movement_one_sale_per_reservation_key
  ON inventory_movement (reservation_id)
  WHERE reason = 'SALE' AND reservation_id IS NOT NULL;

ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_balance_check
  CHECK (quantity_on_hand >= 0 AND quantity_reserved >= 0
    AND quantity_reserved <= quantity_on_hand);
ALTER TABLE inventory_reservation ADD CONSTRAINT inventory_reservation_quantity_check
  CHECK (quantity > 0);
ALTER TABLE cart_item ADD CONSTRAINT cart_item_quantity_check CHECK (quantity > 0);
ALTER TABLE order_item ADD CONSTRAINT order_item_quantity_check CHECK (quantity > 0);
ALTER TABLE cart ADD CONSTRAINT cart_revision_check CHECK (revision >= 0);
ALTER TABLE cart ADD CONSTRAINT cart_exactly_one_owner_check
  CHECK ((user_id IS NOT NULL) <> (guest_token_hash IS NOT NULL));
ALTER TABLE checkout_attempt ADD CONSTRAINT checkout_attempt_input_check CHECK (
  cart_revision >= 0 AND retry_count >= 0 AND fingerprint_version > 0
  AND char_length(idempotency_key) > 0
  AND request_fingerprint::text ~ '^[0-9a-f]{64}$'
);
ALTER TABLE product_variant ADD CONSTRAINT product_variant_signature_check CHECK (
  char_length(option_signature) > 0 AND octet_length(option_signature) <= 1024
  AND octet_length(option_signature) = char_length(option_signature)
);
ALTER TABLE category ADD CONSTRAINT category_not_own_parent_check CHECK (parent_id <> id);
ALTER TABLE inventory_movement ADD CONSTRAINT inventory_movement_sale_reference_check
  CHECK (reason <> 'SALE' OR reservation_id IS NOT NULL);

ALTER TABLE product_variant ADD CONSTRAINT product_variant_money_check CHECK (
  currency = 'USD' AND price >= 0 AND price < 'Infinity'::numeric
  AND (compare_at_price IS NULL OR (compare_at_price >= 0 AND compare_at_price < 'Infinity'::numeric))
);
ALTER TABLE "order" ADD CONSTRAINT order_money_check CHECK (
  currency = 'USD'
  AND subtotal >= 0 AND subtotal < 'Infinity'::numeric
  AND shipping_total >= 0 AND shipping_total < 'Infinity'::numeric
  AND tax_total >= 0 AND tax_total < 'Infinity'::numeric
  AND discount_total >= 0 AND discount_total < 'Infinity'::numeric
  AND grand_total >= 0 AND grand_total < 'Infinity'::numeric
  AND grand_total = subtotal + shipping_total + tax_total - discount_total
);
ALTER TABLE order_item ADD CONSTRAINT order_item_money_check CHECK (
  currency = 'USD'
  AND unit_price >= 0 AND unit_price < 'Infinity'::numeric
  AND line_total >= 0 AND line_total < 'Infinity'::numeric
  AND (tax_total IS NULL OR (tax_total >= 0 AND tax_total < 'Infinity'::numeric))
  AND (discount_total IS NULL OR (discount_total >= 0 AND discount_total < 'Infinity'::numeric))
  AND line_total = quantity * unit_price
);
ALTER TABLE payment ADD CONSTRAINT payment_money_check CHECK (
  currency = 'USD' AND amount >= 0 AND amount < 'Infinity'::numeric
);

COMMIT;
