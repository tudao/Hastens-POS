@isTest
global class POS_Pages_Svcs_test {


static testMethod void test_Pages_Svcs1() {
    // Set up some stock items
    PBSI__Trade_Agreement__c ta1 = new PBSI__Trade_Agreement__c(
    	Name = 'Friends and Family 25% Discount',
    	PBSI__Applies_To__c = 'Sales Order',
    	PBSI__level__c = 'order',
    	PBSI__discount__c = 0.25
    );
    insert ta1;
    PBSI__PBSI_Location__c def1_loc = new PBSI__PBSI_Location__c(
        Name = 'Virtual Part'
    );
    insert def1_loc;
    PBSI__PBSI_Item_Group__c bed_grp = new PBSI__PBSI_Item_Group__c(
        Name = 'Generic Beds',
        PBSI__Item_Group_Code__c = 'GB',
        Avatax_Code__c = 'P0000000'
    );
    insert bed_grp;

    PBSI__PBSI_Item_Group__c accy_grp = new PBSI__PBSI_Item_Group__c(
        Name = 'Accessories',
        PBSI__Item_Group_Code__c = 'Acc',
        Avatax_Code__c = 'P0000000'
    );
    insert accy_grp;
    PBSI__PBSI_Item_Group__c pers_accy_grp = new PBSI__PBSI_Item_Group__c(
        Name = 'Personal Accessories',
        PBSI__Item_Group_Code__c = 'RBS',
        Avatax_Code__c = 'PC040100',
        PBSI__Parent_Group__c = accy_grp.Id
    );
    insert pers_accy_grp;

    PBSI__PBSI_Item_Group__c topm_grp = new PBSI__PBSI_Item_Group__c(
        Name = 'Top Mattresses',
        PBSI__Item_Group_Code__c = 'TOP',
        Avatax_Code__c = 'P0000000'
    ); 
    insert topm_grp;

    PBSI__PBSI_Item__c clip_itm3 = new PBSI__PBSI_Item__c(
        PBSI__Item_Group__c = accy_grp.Id,
        Name = '137070',
        PBSI__description__c = 'VIP Fitting Continental /Frame beds',
        CurrencyIsoCode = 'SEK',
        PBSI__defaultunitofmeasure__c = 'EA',
        PBSI__Default_Location__c = def1_loc.Id
    );
    insert clip_itm3;

    PBSI__PBSI_Item__c leg_itm4 = new PBSI__PBSI_Item__c(
        PBSI__Item_Group__c = accy_grp.Id,
        Name = '116355',
        PBSI__description__c = 'Standard Leg 9 Cherry',
        CurrencyIsoCode = 'SEK',
        PBSI__defaultunitofmeasure__c = 'EA',
        PBSI__Default_Location__c = def1_loc.Id
    );
    insert leg_itm4;

    PBSI__PBSI_Item_Group__c model1_grp = new PBSI__PBSI_Item_Group__c(
        Name = 'Luxuria',
        PBSI__Item_Group_Code__c = 'Lux',
        Avatax_Code__c = 'P0000000',
        PBSI__Parent_Group__c = bed_grp.Id
        ,VIP_Clips_for_this_Item_Group__c = clip_itm3.Id
    ); 
    insert model1_grp;
    PBSI__PBSI_Item__c topm1 = new PBSI__PBSI_Item__c(
        PBSI__Item_Group__c = topm_grp.Id,
        Name = 'BJX Luxury',
        PBSI__description__c = 'BJX Luxury Mattress Topper',
        CurrencyIsoCode = 'GBP',
        PBSI__defaultunitofmeasure__c = 'EA',
        PBSI__Default_Location__c = def1_loc.Id
    );
    insert topm1;

    PBSI__PBSI_Item__c itm1 = new PBSI__PBSI_Item__c(
        PBSI__Item_Group__c = bed_grp.Id,
        Name = 'Luxuria King (193x203 cm) BJX Luxury',
        PBSI__description__c = 'Luxuria King (193x203 cm) BJX Luxury',
        CurrencyIsoCode = 'GBP',
        PBSI__defaultunitofmeasure__c = 'EA',
        Item_Size__c = '193x203',
        Mattress_Topper_Choice__c = topm1.Id,
        Model_LU__c = model1_grp.Id,
        PBSI__Default_Location__c = def1_loc.Id
    );
    insert itm1;

    PBSI__PBSI_Item__c itm2 = new PBSI__PBSI_Item__c(
        PBSI__Item_Group__c = pers_accy_grp.Id,
        Name = '54304',
        PBSI__description__c = 'Children\'s Pyjamas Blue Ck 100 Percale',
        CurrencyIsoCode = 'SEK',
        PBSI__defaultunitofmeasure__c = 'EA',
        PBSI__Default_Location__c = def1_loc.Id
    );
    insert itm2;


    // Set up an account    
    Map<String,String> acc_dtls = new Map<String,String>{'FirstName' => 'a','LastName' => 'a','Phone' => '1234',
        'BillingCountry' => 'USA','BillingPostalCode' => '08201-1415','BillingStreet' => '701 White Horse Pike'};
    Map<String,String> acc_dtls2 = new Map<String,String>{'FirstName' => 'a','LastName' => 'a','Phone' => '1234',
        'BillingStreet' => '701 White Horse Pike'};
    Map<String,Object> ua_res = POS_Pages_Svcs.upsert_acc(acc_dtls2,'Customer Account'); // Missing field err case
    Map<String,String> acc_dtls3 = new Map<String,String>{'FirstName' => 'a','LastName' => 'a','Phone' => '1234',
        'BillingCountry' => 'Canada','BillingPostalCode' => '08201-1415','BillingStreet' => '701 White Horse Pike'};
Test.StartTest();
    ua_res = POS_Pages_Svcs.upsert_acc(acc_dtls,'Customer Account');
    system.debug('upsert_acc:');
    system.debug(ua_res);
    Id acc_id;
    if(ua_res.get('success')==1) {
        Account a1 = (Account)ua_res.get('account');
        acc_id = a1.Id;

        acc_dtls.put('LastName', 'b');
        acc_dtls.put('Id', acc_id);
        ua_res = POS_Pages_Svcs.upsert_acc(acc_dtls,'Customer Account');
        system.debug('upsert_acc2:');
        system.debug(ua_res);
    }

    // Set up a quote
    Map<String,Object> res1 = POS_Pages_Svcs.new_quote(acc_id);
    system.debug('new_quote:');
    system.debug(res1);
    PBSI__Quote__c q1 = (PBSI__Quote__c)res1.get('quote');
    Id q_id = q1.Id;
    system.debug('q_id:');
    system.debug(q_id);
    q1.CurrencyIsoCode = 'USD';
    update q1;

    Map<String,String> bed_dtls = new Map<String,String>{'topm_id' => topm1.Id,'item_id' => itm1.Id
        ,'model_id' => model1_grp.Id,'bed_range_IGC'=>'CB','bed_range'=>'Continental Beds','vip_clips'=>'true'};
    res1 = POS_Pages_Svcs.list_bed_options(bed_dtls);
    system.debug('list_bed_options:');
    system.debug(res1);
    res1 = POS_Pages_Svcs.upsert_bed_line(q_id,bed_dtls);
    system.debug('upsert_bed_line:');
    system.debug(res1);
    PBSI__Quote_Line__c q_l  = (PBSI__Quote_Line__c)res1.get('q_l');
    Id ql_id = q_l.Id;
    bed_dtls.put('ql_id',ql_id);

    PBSI__Quote_Line__c q_l_l2  = new PBSI__Quote_Line__c(
        PBSI__Item__c = leg_itm4.Id
        ,PBSI__Parent_Line__c = q_l.Id
        ,PBSI__Quote__c = q1.Id
        ,PBSI__Quantity__c =1
    );
    insert q_l_l2;

	q1.PBSI__Trade_Agreement__c = ta1.Id;
	q1.PBSI__Discount__c = 0.1;
	update q1;


    Map<String,String> accy_dtls1 = new Map<String,String>{'accy_num' => '54304'};
    Map<String,String> accy_dtls2 = new Map<String,String>{'item_id' => pers_accy_grp.Id};
    res1 = POS_Pages_Svcs.upsert_accy_line(q_id,accy_dtls1);
    res1 = POS_Pages_Svcs.list_accy_options(accy_dtls1,0);
    res1 = POS_Pages_Svcs.list_accy_options(accy_dtls2,0);

    // Test account functions
    res1 = POS_Pages_Svcs.search_acc_zip('');
    res1 = POS_Pages_Svcs.search_acc_zip('0123');
    res1 = POS_Pages_Svcs.search_acc_name('');
    res1 = POS_Pages_Svcs.search_acc_name('0123');
    res1 = POS_Pages_Svcs.orders_4acc(acc_id);

    // Test other functions
    res1 = POS_Pages_Svcs.do_avatax_check(acc_id, true);
    res1 = POS_Pages_Svcs.do_avatax_quote_check(q_id,false, true);
    res1 = POS_Pages_Svcs.quote_summ_html(q_id);
    res1 = POS_Pages_Svcs.upd_ql_qty(ql_id,5);

    res1 = POS_Pages_Svcs.do_POS_quote2so(q_id);
    system.debug('do_POS_quote2so:');
    system.debug(res1);
    Id so_id = (Id)res1.get('so_id');
    res1 = POS_Pages_Svcs.order_summ_html(so_id);

    res1 = POS_Pages_Svcs.upd_q_shipp_amt(q_id,3.5);
    res1 = POS_Pages_Svcs.upd_ord_shipp_amt(so_id,3.5);

    res1 = POS_Pages_Svcs.get_disc_ql(ql_id);
    res1 = POS_Pages_Svcs.set_disc_ql(ql_id,'main',0.2);
    res1 = POS_Pages_Svcs.set_disc_ql(ql_id,'legs',0.2);


    res1 = POS_Pages_Svcs.del_bed_line(q_id,bed_dtls);
Test.StopTest();
}
}