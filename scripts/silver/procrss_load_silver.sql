/*
=====================================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
=====================================================================================

Script Purpose :
	This stored procedure performs the ETL (Extract, Transform, Load) process
	to populate the 'Silver' schema tables from the 'Bronze' schema.

Actions Performed :
	- Truncate Silver Tables
	- Inserts transformed and cleaned data from Bronze into Silver tables.

Parameters :
	None.
	This stored procedure does not accept any parameters or returns any values.

Usage Example :
		EXEC silver.load_silver;

*/



create or alter procedure silver.load_silver as
begin

declare @start_time datetime, @end_time datetime, @batch_start_time datetime, @batch_end_time datetime;

begin try

set @start_time = GETDATE();

PRINT '=================================================';
PRINT 'Loading the Silver Layer';
PRINT '=================================================';

PRINT '-------------------------------------------------';
PRINT 'Loading CRM Tables';
PRINT '-------------------------------------------------';

--1-------------------------------------------------------------
set @batch_start_time = getdate();

print '>>Truncating Table : silver.crm_cust_info';
truncate table silver.crm_cust_info;
print '>>Inserting Data Into : silver.crm_cust_info';
insert into silver.crm_cust_info
(
	cst_id,
	cst_key,
	cst_firstname,
	cst_lastname,
	cst_material_status,
	cst_gndr,
	cst_create_date
)
select 
	cst_id,	
	cst_key,
	trim(cst_firstname) cst_firstname,
	trim(cst_lastname) cst_lastname, 
	case 
		when upper(trim(cst_material_status)) = 'M' then 'Married'
		when upper(trim(cst_material_status)) = 'S' then 'Single'
		else 'n/a'
	end cst_marital_status,
	case 
		when upper(trim(cst_gndr)) = 'F' then 'Female'
		when upper(trim(cst_gndr)) = 'M' then 'Male'
		else 'n/a'
	end cst_gndr,
	cst_create_date
from(select *, 
	row_number() over (partition by cst_id order by cst_create_date desc) rownum
	from bronze.crm_cust_info
) t where rownum = 1 and cst_id is not null

set @batch_end_time = getdate();

PRINT'>> Load Duration: '+CAST(DATEDIFF(SECOND,@start_time,@end_time) as NVARCHAR) + 'seconds';
print'------------------------------------------------------------------------------'

--2--------------------------------------------------------------
set @batch_start_time = getdate();

print '>>Truncating Table : silver.crm_prd_info';
truncate table silver.crm_prd_info;
print '>>Inserting Data Into : silver.crm_prd_info';
INSERT INTO silver.crm_prd_info 
(
		prd_id,
		cat_id,
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt
)
select prd_id,
	   replace(substring(prd_key, 1,5), '-', '_') as cat_id,
	   substring(prd_key, 7,len(prd_key)) as prd_key,
	   prd_nm,
	   isnull(prd_cost, 0) as prd_cost,
	   case 
		   when upper(trim(prd_line)) = 'M' then 'Mountain'
		   when upper(trim(prd_line)) = 'T' then 'Touring'
		   when upper(trim(prd_line)) = 'R' then 'Road'
		   when upper(trim(prd_line)) = 'S' then 'Other Sales'
	       else 'N/A'
	   end as prd_line,
	   cast(prd_start_dt as date) as prd_start_dt,
	   cast(lead(prd_start_dt) over (partition by prd_key order by prd_start_dt) - 1 as date) as prd_end_dt
	   from bronze.crm_prd_info
	   
set @batch_end_time = getdate();

PRINT'>> Load Duration: '+CAST(DATEDIFF(SECOND,@start_time,@end_time) as NVARCHAR) + 'seconds';
print'------------------------------------------------------------------------------'


--3--------------------------------------------------------------
set @batch_start_time = getdate();

print '>>Truncating Table : silver.crm_sales_details';
truncate table silver.crm_sales_details;
print '>>Inserting Data Into : silver.crm_sales_details';
insert into silver.crm_sales_details
(
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	sls_order_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quality,
	sls_price
)
select 
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	case 
		when sls_order_dt = 0 or len(sls_order_dt) != 8 then NULL 
		else cast(cast(sls_order_dt as varchar) as date)
	end as sls_order_dt,
	case 
		when sls_ship_dt =0 or len(sls_ship_dt)!=8 then NULL
		else cast(cast(sls_ship_dt as varchar)as date)
	end as sls_ship_dt,
	case 
		when sls_due_dt = 0 or len(sls_due_dt)!=8 then NULL
		else cast(cast(sls_due_dt as varchar)as date)
	end as sls_due_dt,
	case 
		when sls_sales is null or sls_sales <=0 or sls_sales != sls_quality * abs(sls_price)
		then sls_quality * abs(sls_price) 
		else sls_sales
	end as sls_sales,
	sls_quality,
	case
		when sls_price is null or sls_price <=0 
		then sls_sales / nullif(sls_quality,0 ) 
		else sls_price
	end as sls_price
		from bronze.crm_sales_details


set @batch_end_time = getdate();

PRINT'>> Load Duration: '+CAST(DATEDIFF(SECOND,@start_time,@end_time) as NVARCHAR) + 'seconds';




PRINT '-------------------------------------------------';
PRINT 'Loading ERP Tables';
PRINT '-------------------------------------------------';

--4--------------------------------------------------------------
set @batch_start_time = getdate();

print '>>Truncating Table : silver.erp_cust_az12';
truncate table silver.erp_cust_az12;
print '>>Inserting Data Into : silver.erp_cust_az12';
insert into silver.erp_cust_az12
(
	cid,
	bdate,
	gen
)
select
	case 
		when cid like 'NAS%' then substring(cid,4, len(cid))
		else cid
	end as cid,
	case when bdate > getdate() then NULL
		else bdate
	end as bdate,
	case 
		when upper(trim(gen)) in ('M', 'MALE') then 'Male'
		when upper(trim(gen)) in ('F','FEMALE') then 'Female'
		else 'n/a'
	end as gen
	from bronze.erp_cust_az12

	set @batch_end_time = getdate();

PRINT'>> Load Duration: '+CAST(DATEDIFF(SECOND,@start_time,@end_time) as NVARCHAR) + 'seconds';
print'------------------------------------------------------------------------------'


--5--------------------------------------------------------------
set @batch_start_time = getdate();

print '>>Truncating Table : silver.erp_loc_a101';
truncate table silver.erp_loc_a101;
print '>>Inserting Data Into : silver.erp_loc_a101';
insert into silver.erp_loc_a101
(
	cid, 
	cntry
)
select 
replace (cid, '-', '') cid, 
case 
	when cntry in ('USA', 'US') THEN 'United States of America'
	when trim(cntry) = 'DE' THEN 'Germany'
	when trim(cntry) = '' or cntry is null then 'n/a'
	else trim(cntry)
end as cntry
from bronze.erp_loc_a101

set @batch_end_time = getdate();

PRINT'>> Load Duration: '+CAST(DATEDIFF(SECOND,@start_time,@end_time) as NVARCHAR) + 'seconds';
print'------------------------------------------------------------------------------'


--6---------------------------------------------------------------
set @batch_start_time = getdate();

print '>>Truncating Table : silver.erp_px_cat_g1v2';
truncate table silver.erp_px_cat_g1v2;
print '>>Inserting Data Into : silver.erp_px_cat_g1v2';
insert into silver.erp_px_cat_g1v2
(
	id,
	cat,
	subcat,
	maintenance
)
select 
	id, 
	cat,	
	subcat, 
	maintenance 
from bronze.erp_px_cat_g1v2

set @batch_end_time = getdate();

PRINT'>> Load Duration: '+CAST(DATEDIFF(SECOND,@start_time,@end_time) as NVARCHAR) + 'seconds';


set @end_time = getdate();

PRINT '=================================================';
PRINT 'Loading the Silver Layer is Complete';
print 'Total Process Duration : '+cast(dateDiff(SECOND,@start_time, @end_time) as nvarchar) + 'seconds';                  
PRINT '=================================================';

end try

begin catch
print'=================================================='
print'ERROR OCCURED DURING LOADING THE SILVER LAYER';
PRINT'ERROR MESSAGE' + ERROR_MESSAGE();
PRINT'ERROR MESSAGE' + CAST(ERROR_NUMBER() AS NVARCHAR);
PRINT'ERROR MESSAGE' + CAST(ERROR_STATE() AS NVARCHAR);
PRINT'=================================================='
END CATCH

END




EXEC silver.load_silver;
