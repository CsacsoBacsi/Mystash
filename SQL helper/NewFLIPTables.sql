-- Procedure to populate the MGMT tables
DECLARE
BEGIN
  AE_MGMT.MGMT_K_HDS_TABLE_UTILS.hds_table_setup
  (
    p_source_db                   => 'settpw01.world' 
  , p_source_owner                => 'FLIP_INVOICE' 
  , p_source_table_name           => 'GAS_INVOICE_DETAIL' 
  , p_target_table_name           => 'HDS_T_FLIP_GAS_INVOICE_DETAIL' 
  , p_table_alias                 => 'FR09' 
  , p_use_goldengate              => 'N'  -- optional (Default 'Y')
  , p_template_ref                => NULL -- optional
  , p_init_load_required          => 'Y'  -- optional (Default 'Y')
  , p_init_load_criteria_required => 'N'  -- optional (Default 'N')
  , p_userid                      => NULL -- optional
  , p_lob_column_name             => NULL -- optional
  );
END;

-- Backing out
DECLARE
  P_TARGET_TABLE_OWNER VARCHAR2(30);
  P_TARGET_TABLE_NAME VARCHAR2(30);
BEGIN
  P_TARGET_TABLE_OWNER := 'AE_HDS';
  P_TARGET_TABLE_NAME := 'HDS_T_FLIP_CHARGE_MPAN_MPR_LNK';
 
  AE_MGMT.MGMT_R_HDS_TABLE_BACKOUT(
    P_TARGET_TABLE_OWNER => P_TARGET_TABLE_OWNER,
    P_TARGET_TABLE_NAME => P_TARGET_TABLE_NAME
  );
END;
