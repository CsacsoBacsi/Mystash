select * from hds_t_ice1_prd_con_dtl ; -- ICE_CUSTOMER_ID, ACCOUNT_REFERENCE (PA), PRODUCT_TYPE, KEY_TYPE, MPAN_MPR
-- Joins PRODUCT_TYPE(ID) (DIM_T_PRODUCT_TYPE), 

select * from ae_dim.dim_t_product ; -- (11) PRODUCT_CODE (E, G, Ums)

select * from ae_dim.dim_t_product_type  -- (819,944) PRODUCT_TYPE_ID, BASE_PRICING, SALES_PRICING, BUSINESS_FLAG, PRODUCT_CATEGORY
where product_type_id = 1748794 ;
-- Joins PRODUCT_GROUP (DIM_T_PRODUCT_GROUP), SUBGROUP_VERSION (DIM_T_PRODUCT_SUBGROUP_VERSION), PRODUCT_CATEGORY (HDS_T_ICE1_PRODUCT_CATEGORY)

select * from ae_hds.hds_t_ice1_product_category ; -- (10) PRODUCT_CATEGORY

select * from ae_dim.dim_t_product_group ; -- MI team proprietory stuff (107) - PRODUCT_GROUP_ID, PRODUCT_GROUP 

select * from ae_dim.dim_t_product_grouping ; -- PRODUCT_TYPE, PRODUCT_TYPE_ID, PRODUCT_CODE, SUBGROUP_VERSION, PRODUCT_GROUP, PRODUCT_FAMILY


select * from ae_dim.dim_t_product_subgroup_detail ; -- (173) PRODUCT_GROUP_ID, SUBGROUP_DETAIL_ID, SUBGROUP_DETAIL
select * from ae_dim.dim_t_product_subgroup_version ; -- (811) SUBGROUP_DETAIL_ID, SUBGROUP_VERSION_ID, SUBGROUP_VERSION
;

select distinct t.product_family from ae_dim.dim_t_product_grouping t 

ae_hsl.hsl_t_ice_prod_con_detail

