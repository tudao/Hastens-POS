global class POS_Pages_Svcs {

public POS_Pages_Svcs() {
}

static String doErr(String msg,String err_code,Map<String,Object> result) {
    result.put('success',0);
    result.put('error_msg',msg);
    result.put('error_code',err_code);
    return JSON.serialize(result);
}

@RemoteAction
global static Map<String,Object> search_acc_zip(String zipc) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(!zipc.isAlphanumericSpace()) { doErr('Not alphanumeric or space.','K001',result); return result; }
    Account[] accs;
    if(null==zipc || ''==zipc.trim()) {
        Id usr_id = UserInfo.getUserId();
        accs = [SELECT Id,Name,BillingPostalCode,BillingStreet FROM Account WHERE CreatedById=:usr_id ORDER BY SystemModstamp DESC LIMIT 20];
    } else accs = [SELECT Id,Name,BillingPostalCode,BillingStreet FROM Account WHERE BillingPostalCode LIKE :('%'+zipc+'%') ORDER BY SystemModstamp DESC LIMIT 20];
    result.put('accounts',accs);
    result.put('success',1);
    return result;
}
@RemoteAction
global static Map<String,Object> search_acc_name(String full_name) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(!full_name.isAlphanumericSpace()) { doErr('Not alphanumeric or space.','K001',result); return result; }
    Account[] accs;
    if(''==full_name.trim()) {
        Id usr_id = UserInfo.getUserId();
        accs = [SELECT Id,Name,BillingPostalCode,BillingStreet FROM Account WHERE CreatedById=:usr_id ORDER BY SystemModstamp DESC LIMIT 20];
    } else accs = [SELECT Id,Name,BillingPostalCode,BillingStreet FROM Account WHERE Name LIKE :('%'+full_name+'%') ORDER BY SystemModstamp DESC LIMIT 20];
    result.put('accounts',accs);
    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> orders_4acc(String acc_id) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==acc_id) { doErr('Account ID must be provided','K001',result); return result; }
    Account acc = [SELECT Id,Name,FirstName,LastName,PersonEmail,Phone,PersonMobilePhone,BillingPostalCode,BillingStreet,BillingCity,BillingState,BillingCountry,RecordTypeId FROM Account WHERE Id=:acc_id LIMIT 1];
    if(null==acc) { doErr('Account not found','K002',result); return result; }
    PBSI__PBSI_Sales_Order__c[] open_orders = [SELECT Id,Name,CreatedDate,PBSI__Final_Order_Total__c,PBSI__Status__c FROM PBSI__PBSI_Sales_Order__c WHERE PBSI__Status__c!='Closed' AND PBSI__Customer__c =:acc_id ORDER BY CreatedDate DESC LIMIT 20];
    PBSI__PBSI_Sales_Order__c[] closed_orders = [SELECT Id,Name,CreatedDate,PBSI__Final_Order_Total__c,PBSI__Status__c FROM PBSI__PBSI_Sales_Order__c WHERE PBSI__Status__c='Closed' AND PBSI__Customer__c =:acc_id ORDER BY CreatedDate DESC LIMIT 20];
    PBSI__PBSI_Sales_Order__c[] orders = new List<PBSI__PBSI_Sales_Order__c>();
    Id[] oids = new List<Id>();
    String[] odates = new List<String>();
    for(PBSI__PBSI_Sales_Order__c so:open_orders) { odates.add(so.CreatedDate.date().format()); orders.add(so); oids.add(so.Id); }
    for(PBSI__PBSI_Sales_Order__c so:closed_orders) { if( oids.size()>=20 ) break; odates.add(so.CreatedDate.date().format()); orders.add(so); oids.add(so.Id); }
    PBSI__PBSI_Sales_Order_Line__c[] so_lines = [SELECT Id,Name,CreatedDate,PBSI__ItemDescription__c,PBSI__Quantity_Needed__c,PBSI__Sales_Order__c FROM PBSI__PBSI_Sales_Order_Line__c WHERE PBSI__Sales_Order__c IN :oids ORDER BY Name];

    PBSI__Quote__c[] open_quotes = [SELECT Id,Name,CreatedDate,POS_Final_Quote_Total__c,PBSI__Status__c FROM PBSI__Quote__c WHERE PBSI__Status__c='Active' AND PBSI__Account__c =:acc_id ORDER BY CreatedDate DESC LIMIT 20];
    Id[] q_ids = new List<Id>();
    String[] q_dates = new List<String>();
    for(PBSI__Quote__c q:open_quotes) { q_dates.add(q.CreatedDate.date().format()); q_ids.add(q.Id); }
    PBSI__Quote_Line__c[] q_lines = [SELECT Id,Name,CreatedDate,PBSI__Description__c,Bed_Description__c,PBSI__Quantity__c,PBSI__Quote__c,PBSI__Item__r.PBSI__Item_Group__r.PBSI__Item_Group_Code__c FROM PBSI__Quote_Line__c WHERE PBSI__Quote__c IN :q_ids ORDER BY CreatedDate];

    map<Id,String> a_rts = new map<Id,String>();
    for(Schema.RecordTypeInfo a_rt:Account.SObjectType.getDescribe().getRecordTypeInfos() ) a_rts.put( a_rt.getRecordTypeId(), a_rt.getName() );

    result.put('account',acc);
    result.put('a_rts',a_rts);
    result.put('orders',orders);
    result.put('odates',odates);
    result.put('so_lines',so_lines);
    result.put('quotes',open_quotes);
    result.put('q_dates',q_dates);
    result.put('q_lines',q_lines);
    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> upsert_acc(Map<String,String> acc_dtls,String a_rt_n) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    Id a_rt_id;
    map<Id,String> a_rts = new map<Id,String>();
    for(Schema.RecordTypeInfo a_rt:Account.SObjectType.getDescribe().getRecordTypeInfos() ) {
        String rt_id = a_rt.getRecordTypeId();
        String rt_name = a_rt.getName();
        a_rts.put( rt_id, rt_name );
        if( rt_name == a_rt_n ) a_rt_id = rt_id;
    }

    Boolean isPersonAcct = true;

    Account acc;
    if(null!=acc_dtls.get('Id')) {
        String acc_id = acc_dtls.get('Id');
        acc = [SELECT Id,RecordTypeId,FirstName,LastName,PersonEmail,Phone,PersonMobilePhone,BillingPostalCode,BillingStreet,BillingCity,BillingState,BillingCountry,Business_Address_Street__pc,Business_Address_City__pc,Business_Address_State_Province__pc,Business_Address_Country__pc,Business_Address_Zip_Postal_Code__pc FROM Account WHERE Id=:acc_id LIMIT 1];
        if( 'Customer Account' != a_rts.get(acc.RecordTypeId) ) isPersonAcct = false;
    } else if(null != a_rt_id) {
        acc = new Account(RecordTypeId = a_rt_id);
        isPersonAcct = ( 'Customer Account' == a_rt_n );
    } else {
        acc = new Account();
        isPersonAcct = true;
    }

    if(isPersonAcct) {
        acc.FirstName= acc_dtls.get('FirstName');
        acc.LastName= acc_dtls.get('LastName');
    } else {
        acc.Name= acc_dtls.get('Name');
    }
    acc.Phone = acc_dtls.get('Phone');

    String a_BillingStreet = acc_dtls.get('BillingStreet');
    String a_BillingCity = acc_dtls.get('BillingCity');
    String a_BillingState = acc_dtls.get('BillingState');
    String a_BillingCountry = acc_dtls.get('BillingCountry');
    String a_BillingPostalCode= acc_dtls.get('BillingPostalCode');

    acc.BillingStreet = a_BillingStreet;
    acc.BillingCity = a_BillingCity;
    acc.BillingState = a_BillingState;
    acc.BillingCountry = a_BillingCountry;
    acc.BillingPostalCode= a_BillingPostalCode;

    if(isPersonAcct) {
        acc.PersonEmail = acc_dtls.get('PersonEmail');
        acc.PersonMobilePhone = acc_dtls.get('PersonMobilePhone');
        acc.Business_Address_Street__pc = a_BillingStreet;
        acc.Business_Address_City__pc = a_BillingCity;
        acc.Business_Address_State_Province__pc = a_BillingState;
        acc.Business_Address_Country__pc = a_BillingCountry;
        acc.Business_Address_Zip_Postal_Code__pc = a_BillingPostalCode;
    }

    try {
        upsert acc;
    } catch (Exception e) {
        String errM = e.getMessage();
        if(errM.contains('REQUIRED_FIELD_MISSING')) { String err_fld = errM.substringBetween('[',']') + ' cannot be blank.';
            if(err_fld.startsWith('Business Address ')) err_fld = err_fld.substring(17); doErr(err_fld,'D002',result); return result;
        } else { doErr('Could not update account.'+errM,'D001',result); return result; }
    }
    acc = [SELECT Id,RecordTypeId,Name,FirstName,LastName,PersonEmail,Phone,PersonMobilePhone,BillingPostalCode,BillingStreet,BillingCity,BillingState,BillingCountry FROM Account WHERE Id=:acc.Id LIMIT 1];

    result.put('account',acc);
    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> do_avatax_check(Id acc_id,Boolean cvg_test) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==acc_id) { doErr('Account ID must be provided','K001',result); return result; }
    Account acc;
    acc = [SELECT Id,FirstName,LastName,PersonEmail,Phone,PersonMobilePhone,BillingPostalCode,BillingStreet,BillingCity,BillingState,BillingCountry FROM Account WHERE Id=:acc_id LIMIT 1];

    set<String> avatax_regions = new set<String>{'USA','US','CANADA'};
    String cc = ( null== acc.BillingCountry ? '' : acc.BillingCountry );
    cc = cc.remove('.').toUpperCase();
    if( ! avatax_regions.contains(cc) ) {
        result.put('tax_region','International');
        result.put('valid',true);
        result.put('account',acc);
        result.put('success',1);
        return result;
    }
    result.put('tax_region',cc);

    List<POS_Tax_Settings__c> tax_sett = POS_Tax_Settings__c.getall().values();  // Custom settings if avail

    AVA_SF_SDK.AddressSvc.AddressSvcSoap addressSvc;
    if( null!= tax_sett && 1== tax_sett.size() ) addressSvc = new AVA_SF_SDK.AddressSvc.AddressSvcSoap('https://avatax.avalara.net');
    else addressSvc = new AVA_SF_SDK.AddressSvc.AddressSvcSoap('https://development.avalara.net');

    addressSvc.Security = new AVA_SF_SDK.AddressSvc.Security();

    if( null!= tax_sett && 1== tax_sett.size() ) {
        addressSvc.Security.UsernameToken.Username = tax_sett[0].AvaTax_Account__c;
        addressSvc.Security.UsernameToken.Password = tax_sett[0].AvaTax_License_Key__c;
    } else {
        addressSvc.Security.UsernameToken.Username = '1100127154';
        addressSvc.Security.UsernameToken.Password = 'D509E563742937C5';
    }

    addressSvc.Profile.Client = 'HastensValidateTest,1,0';
    
    AVA_SF_SDK.AddressSvc.ValidateRequest vreq = new AVA_SF_SDK.AddressSvc.ValidateRequest();
    vreq.Address = new AVA_SF_SDK.AddressSvc.BaseAddress();
    vreq.Address.TaxRegionId=0;
    vreq.Coordinates = false;
    vreq.Taxability=false;
    vreq.TextCase='Mixed';

    vreq.Address.Line1 = acc.BillingStreet;
    vreq.Address.City = acc.BillingCity;
    vreq.Address.Region = acc.BillingState;
    vreq.Address.PostalCode = acc.BillingPostalCode;
    
    AVA_SF_SDK.AddressSvc.ValidateResult vres;
    try
    {
        if(!cvg_test) vres = addressSvc.Validate(vreq);
    }
    catch(Exception ex)
    {
        doErr('Address Validation Excepted' + ex.getmessage(),'D001',result); return result;
    }
    if(null!= vres && vres.ResultCode == 'Success')
    {
        result.put('valid',true);
        result.put('valid_line1',vres.ValidAddresses.ValidAddress[0].Line1);
        result.put('valid_line4',vres.ValidAddresses.ValidAddress[0].Line4);
    }
    else
    {
        result.put('valid',false);
        if(null!=vres) { result.put('addr_err_msg_name',vres.Messages.Message[0].Name); result.put('addr_err_msg_smry',vres.Messages.Message[0].Summary); }
    }

    result.put('account',acc);
    result.put('success',1);
    return result;
}

static String o_fmt_col_1(String cls_name,String txt) {
    return '<td class="'+cls_name+'"><div>'+txt+'</div></td>';
}
static String o_fmt_col_2(String cls_name,String txt) {
    return '<td><div class="'+cls_name+'">'+txt+'</div></td>';
}
static String o_fmt_col_i_nval1(String cls_name,String cls_name_div,String id,Decimal v) {
    return '<td class="'+cls_name+'"><div class="'+cls_name_div+'" ql_id="'+id+'">'+ (null==v ? '' : '<div class="ql-qty">'+v+'</div>' )
        +'</div><div><a ql_id="'+id
        +'" class="ql_edit_btn" href="#" data-role="button" data-icon="edit" data-iconpos="notext" data-theme="c" data-inline="true">Edit</a></div></td>';
}
static String o_fmt_col_i_nval2(String cls_name,String cls_name_div,String id,Decimal v) {
    return '<td class="'+cls_name+'"><div class="'+cls_name_div+'" ql_id="'+id+'">'+ (null==v ? '' : '<div class="ql-qty">'+v+'</div>' )
        +'</div></td>';
}
static String o_fmt_col_cval1(String cls_name,String ccy,Decimal v) {
    return '<td><div class="'+cls_name+'">'+ (null==v ? '' : '<div class="ql-val"><span class="o_ccy">'+ccy+' </span>'+v.setScale(2)+'</div>' )+'</div></td>';
}
static String o_fmt_col_edit_cval1(String cls_name,String ccy,Decimal v) {
    return '<td class="col4"><a class="ship_edit_btn" href="#" data-role="button" data-icon="edit" data-iconpos="notext" data-theme="c" data-inline="true">Edit</a><div class="'+cls_name+' ql_inl">'+ (null==v ? '' : '<div class="ql-val"><span class="o_ccy">'+ccy+' </span>'+v.setScale(2)+'</div>' )+'</div></td>';
}
static String o_fmt_col_pval1(String cls_name,Decimal v) {
    return '<td><div class="'+cls_name+'">'+ (null==v ? '' : '<div class="ql-val">'+v+'%</div>' )+'</div></td>';
}
static String o_fmt_col_i_pval1(String cls_name,String id,Decimal v) {
    return '<td><div class="'+cls_name+'">'+ (null==v ? '' : '<div class="ql-val">'+v+'%</div>' )+'</div><div class="ql_disc_bc"><a ql_id="'+id
        +'" class="ql_disc_btn" href="#" data-role="button" data-icon="edit" data-iconpos="notext" data-theme="c" data-inline="true">Edit</a></div></td>';
}
static void fcr_2(String [] attrHTs,String attr_id_cls,String lbl,String fval) {
    if(null!=fval) attrHTs.add('<div class="qut_line '+attr_id_cls+'"><span class="ql-lbl">'+lbl+':</span><span class="ql-val">'+fval+'</span></div>');
}
static String o_fmt_line1(String attr_id_cls,String lbl,String fval) {
    return (null==fval ? '' : '<div class="qut_line '+attr_id_cls+'"><span class="ql-lbl">'+lbl+':</span><span class="ql-val">'+fval+'</span></div>');
}
static String o_fmt_line2(String attr_id_cls,String lbl,String fval) {
    return (null==fval || 'x'==fval || '000x000'==fval ? '' : '<div class="qut_line '+attr_id_cls+'"><span class="ql-lbl">'+lbl+':</span><span class="ql-val">'+fval+'</span></div>');
}
static String o_fmt_bed_Bed_ord(String cls_name,PBSI__PBSI_Sales_Order_Line__c bed) {
    return '<td><div class="'+cls_name+'">'
//      +o_fmt_line1('bsm-range','Range',bed.PBSI__Item__r.Range_LU__r.Name)
        +o_fmt_line1('bsm-model','Model',bed.PBSI__Item__r.Model_LU__r.Name)
        +o_fmt_line1('bsm-firmness','Firmness',bed.PBSI__Item__r.Firmness_Options__c)
        +o_fmt_line2('bsm-size','Size',bed.PBSI__Item__r.Bed_Size__c)
        +o_fmt_line1('bsm-color','Fabric',bed.PBSI__Item__r.Color__c)
        +o_fmt_line1('bsm-top_mattress','Mattress Topper',bed.Bed_Topper__r.Name)
        +o_fmt_line1('bsm-legs','Legs',bed.Bed_Legs__r.PBSI__description__c)
        +o_fmt_line1('bsm-clips','VIP Clips?',bed.VIP_Clips__c ? 'Yes' : 'No')  
        +'</div></td>';
}

static String cust_opts_spec_q(PBSI__Quote_Line__c bed) {
    return ( null== bed.Bed_Custom_Base__c ? 'One Piece' : bed.Bed_Custom_Base__c ) + ' / ' + ( null== bed.Bed_Custom_Mattress__c ? 'One Piece' : bed.Bed_Custom_Mattress__c );
}
static String o_fmt_bed_GBed_quot(String cls_name,PBSI__Quote_Line__c bed) {
    return '<td><div class="'+cls_name+'">'
//      +o_fmt_line1('bsm-range','Range',bed.PBSI__Item__r.Range_LU__r.Name)
        +o_fmt_line1('bsm-model','Model',bed.PBSI__Item__r.Model_LU__r.Name)
        +o_fmt_line1('bsm-firmness','Firmness',( null== bed.Bed_Custom_Firmness__c ? bed.Firmness__c : bed.Bed_Custom_Firmness__c ))
        +o_fmt_line1('bsm-options','Base/Mattress',cust_opts_spec_q(bed) )
        +o_fmt_line2('bsm-size','Size',( null== bed.Bed_Custom_Size__c ? bed.PBSI__Item__r.Bed_Size__c : bed.Bed_Custom_Size__c ))
        +o_fmt_line1('bsm-color','Fabric',bed.Fabric_Colour__c)
        +o_fmt_line1('bsm-top_mattress','Mattress Topper',bed.Bed_Topper__r.PBSI__description__c)
//      +o_fmt_line1('bsm-legs','Legs',bed.Bed_Legs__r.PBSI__description__c)
//      +o_fmt_line1('bsm-clips','VIP Clips?',bed.VIP_Clips__c ? 'Yes' : 'No')  
        +'</div></td>';
}

static String cust_opts_spec_so(PBSI__PBSI_Sales_Order_Line__c bed) {
    return ( null== bed.Bed_Custom_Base__c ? 'One Piece' : bed.Bed_Custom_Base__c ) + ' / ' + ( null== bed.Bed_Custom_Mattress__c ? 'One Piece' : bed.Bed_Custom_Mattress__c );
}
static String o_fmt_bed_GBed_ord(String cls_name,PBSI__PBSI_Sales_Order_Line__c bed) {
    return '<td><div class="'+cls_name+'">'
//      +o_fmt_line1('bsm-range','Range',bed.PBSI__Item__r.Range_LU__r.Name)
        +o_fmt_line1('bsm-model','Model',bed.PBSI__Item__r.Model_LU__r.Name)
        +o_fmt_line1('bsm-firmness','Firmness',( null== bed.Bed_Custom_Firmness__c ? bed.Firmness__c : bed.Bed_Custom_Firmness__c ))
        +o_fmt_line1('bsm-options','Base/Mattress',cust_opts_spec_so(bed) )
        +o_fmt_line2('bsm-size','Size',( null== bed.Bed_Custom_Size__c ? bed.PBSI__Item__r.Bed_Size__c : bed.Bed_Custom_Size__c ))
        +o_fmt_line1('bsm-color','Fabric',bed.Fabric_Colour__c)
        +o_fmt_line1('bsm-top_mattress','Mattress Topper',bed.Bed_Topper__r.Name)
//      +o_fmt_line1('bsm-legs','Legs',bed.Bed_Legs__r.PBSI__description__c)
//      +o_fmt_line1('bsm-clips','VIP Clips?',bed.VIP_Clips__c ? 'Yes' : 'No')  
        +'</div></td>';
}
static String o_fmt_accy_1(String cls_name,PBSI__PBSI_Item__c accy,String line_desc) {
    if(null!=accy)
        return '<td><div class="'+cls_name+'">'
        +o_fmt_line1('bsm-desc','Description',(null==line_desc || ''==line_desc ? accy.PBSI__description__c : line_desc) )
        +o_fmt_line2('bsm-size','Size',accy.Bed_Size__c)
        +o_fmt_line1('bsm-color','Fabric',accy.Color__c)
        +o_fmt_line1('bsm-inum','Item Num.',accy.Name)
        +'</div></td>';
    else
        return '<td><div class="'+cls_name+'">'
        +o_fmt_line1('bsm-desc','Description','[Unknown / Deleted Item]')
        +'</div></td>';
}
static String o_fmt_unkn_1(String cls_name) {
    return '<td><div class="'+cls_name+'">'
        +o_fmt_line1('bsm-desc','Description','[Unknown Item]')
        +'</div></td>';
}
static String o_fmt_bed_part_1(String cls_name,PBSI__PBSI_Item__c accy) {
    if(null!=accy)
        return '<td><div class="'+cls_name+'">'
        +o_fmt_line1('bsm-desc','Description',accy.PBSI__description__c)
        +o_fmt_line2('bsm-size','Size',accy.Bed_Size__c)
        +o_fmt_line1('bsm-color','Fabric',accy.Color__c)
//      +o_fmt_line1('bsm-inum','Item Num.',accy.Name)
        +'</div></td>';
    else
        return '<td><div class="'+cls_name+'">'
        +o_fmt_line1('bsm-desc','Description','[Unknown / Deleted Item]')
        +'</div></td>';
}
static String o_fmt_addr_1(Account a) {
    String addr = '';
    if(null!=a.Name) addr += '<div>'+ a.Name +'</div>';
    if(null!=a.BillingStreet) addr += '<div>'+ a.BillingStreet +'</div>';
    if(null!=a.BillingCity) addr += '<div>'+ a.BillingCity +'</div>';
    if(null!=a.BillingState) addr += '<div>'+ a.BillingState +'</div>';
    if(null!=a.BillingCountry) addr += '<div>'+ a.BillingCountry +'</div>';
    if(null!=a.BillingPostalCode) addr += '<div>'+ a.BillingPostalCode +'</div>';
    return addr;
}
static String o_fmt_ctct_1(Account a) {
    String c = '';
    if(null!=a.Name) c += '<div>'+ a.Name +'</div>';
    if(null!=a.PersonEmail) c += '<div>'+ a.PersonEmail +'</div>';
    if(null!=a.Phone) c += '<div>'+ a.Phone +'</div>';
    return c;
}

@RemoteAction
global static Map<String,Object> do_avatax_quote_check(String qt_id,Boolean do_checkout,Boolean cvg_test) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==qt_id) { doErr('Quote ID must be provided','K001',result); return result; }
    PBSI__Quote__c[] qs = [SELECT Id,Name,Quote_Number__c,CreatedDate,POS_Final_Quote_Total__c,POS_Net_Quote_Total__c,
    PBSI__Sales_Tax__c,Total_Sales_Tax_Avatax__c,Actual_Total_Sales_Tax__c,PBSI__Status__c,PBSI__Account__c FROM PBSI__Quote__c WHERE Id=:qt_id LIMIT 1];

    if(0==qs.size()) { doErr('Quote cannot be found','K002',result); return result; }
    if(null==qs[0].PBSI__Account__c) { doErr('Quote has no Account ID','K003',result); return result; }
    PBSI__Quote__c q = qs[0];
    Id acc_id = qs[0].PBSI__Account__c;
    Account acc = [SELECT Id,Name,FirstName,LastName,PersonEmail,Phone,BillingPostalCode,BillingStreet,BillingCity,BillingState,BillingCountry FROM Account WHERE Id=:acc_id LIMIT 1];
    if(null==acc) { doErr('Account not found','K002',result); return result; }

    set<String> avatax_regions = new set<String>{'USA','US','CANADA'};
    String cc = ( null== acc.BillingCountry ? '' : acc.BillingCountry );
    cc = cc.remove('.').toUpperCase();
    if( ! avatax_regions.contains(cc) ) {
        result.put('tax_region','International');
        result.put('valid',true);
        result.put('account',acc);
        result.put('success',1);
        return result;
    }
    result.put('tax_region',cc);

    set<String> bed_IGCs = new set<String>{'GB'};
    PBSI__Quote_Line__c[] q_lines = [SELECT Id,Name,CreatedDate,PBSI__Description__c,PBSI__Quantity__c,PBSI__Quote__c,PBSI__Parent_Line__c,PBSI__Item__c,
        POS_Discounted_Price__c,POS_Line_Subtotal__c, SalesTax_Rate_Avatax__c,
        PBSI__Item__r.PBSI__Item_Group__r.Avatax_Code__c, PBSI__Item_SOLine_Description__c,PBSI__Item__r.Name
        FROM PBSI__Quote_Line__c WHERE PBSI__Quote__c =:qt_id ORDER BY CreatedDate];

    for(PBSI__Quote_Line__c q_l:q_lines) if(null== q_l.PBSI__Item__r.PBSI__Item_Group__r.Avatax_Code__c) {
        errors.add('Missing Tax Code for Item: '+q_l.PBSI__Item__r.Name);
    }
    if( errors.size() > 0 ) {
        result.put('tax_errors',errors);
        doErr('Missing Tax Codes.','D001',result); 
        return result;
    }
    PBSI__Quote_Line__c[] upd_q_lines = new list<PBSI__Quote_Line__c>();

    List<POS_Tax_Settings__c> tax_sett = POS_Tax_Settings__c.getall().values();  // Custom settings if avail

    AVA_SF_SDK.TaxSvc.TaxSvcSoap taxSvc;
    if( null!= tax_sett && 1== tax_sett.size() ) taxSvc = new AVA_SF_SDK.TaxSvc.TaxSvcSoap('https://avatax.avalara.net');
    else taxSvc = new AVA_SF_SDK.TaxSvc.TaxSvcSoap('https://development.avalara.net');
    taxSvc.Security = new AVA_SF_SDK.TaxSvc.Security();
    if( null!= tax_sett && 1== tax_sett.size() ) {
        taxSvc.Security.UsernameToken.Username = tax_sett[0].AvaTax_Account__c;
        taxSvc.Security.UsernameToken.Password = tax_sett[0].AvaTax_License_Key__c;
    } else {
        taxSvc.Security.UsernameToken.Username = '1100127154';
        taxSvc.Security.UsernameToken.Password = 'D509E563742937C5';
    }
    taxSvc.Profile = new AVA_SF_SDK.TaxSvc.Profile();
    taxSvc.Profile.Client = 'HastensGetTaxTest,1,0';

    AVA_SF_SDK.TaxSvc.GetTaxRequest gtreq = new AVA_SF_SDK.TaxSvc.GetTaxRequest();
    gtreq.DocCode = q.Quote_Number__c;
    // SalesOrder, SalesInvoice, ReturnOrder, ReturnInvoice, PurchaseOrder, PurchaseInvoice
    gtreq.DocType = ( do_checkout ? 'SalesInvoice' : 'SalesOrder' );
    gtreq.CustomerCode = acc.Name;
    gtreq.CompanyCode = ( cc=='CANADA' ? 'HBCI' : 'HBI');
    // Document (default), Line, Tax
    gtreq.DetailLevel = 'Tax';

    AVA_SF_SDK.TaxSvc.BaseAddress orgAddr = new AVA_SF_SDK.TaxSvc.BaseAddress();
    orgAddr.AddressCode = 'Origin';
    if(cc=='CANADA') {
        if( null!= tax_sett && 1== tax_sett.size() ) {
            orgAddr.Line1 = tax_sett[0].Tax_Origin_CANADA_Line1__c; orgAddr.City = tax_sett[0].Tax_Origin_CANADA_City__c;
            orgAddr.Region = tax_sett[0].Tax_Origin_CANADA_Region__c; orgAddr.PostalCode = tax_sett[0].Tax_Origin_CANADA_PostalCode__c;
        } else {
            orgAddr.Line1 = '18 Distillery Lane'; // orgAddr.Line2 = '[adress line 2]';  orgAddr.Line3 = '[address line 3]';
            orgAddr.City = 'Toronto'; orgAddr.Region = 'ON'; orgAddr.PostalCode = 'M5A 3C4';
        }
    } else {
        if( null!= tax_sett && 1== tax_sett.size() ) {
            orgAddr.Line1 = tax_sett[0].Tax_Origin_US_Line1__c; orgAddr.City = tax_sett[0].Tax_Origin_US_City__c;
            orgAddr.Region = tax_sett[0].Tax_Origin_US_Region__c; orgAddr.PostalCode = tax_sett[0].Tax_Origin_US_PostalCode__c;
        } else {
            orgAddr.Line1 = '876 Broadway';
            orgAddr.City = 'New York';
            orgAddr.Region = 'NY';
            orgAddr.PostalCode = '10003-1224';      
        }
    }

    AVA_SF_SDK.TaxSvc.BaseAddress dstAddr = new AVA_SF_SDK.TaxSvc.BaseAddress();
    dstAddr.AddressCode = 'Destination';
    dstAddr.Line1 = acc.BillingStreet;
    // dstAddr.Line2 = '[adress line 2]';
    // dstAddr.Line3 = '[address line 3]';
    dstAddr.City = acc.BillingCity;
    dstAddr.Region = acc.BillingState;
    dstAddr.PostalCode = acc.BillingPostalCode;


    gtreq.Addresses = new AVA_SF_SDK.TaxSvc.ArrayOfBaseAddress();
    gtreq.Addresses.BaseAddress = new AVA_SF_SDK.TaxSvc.BaseAddress[2];
    gtreq.Addresses.BaseAddress[0] = orgAddr;
    gtreq.Addresses.BaseAddress[1] = dstAddr;

    gtreq.OriginCode = orgAddr.AddressCode;
    gtreq.DestinationCode = dstAddr.AddressCode;

    AVA_SF_SDK.TaxSvc.Line[] tax_rq_lines = new list<AVA_SF_SDK.TaxSvc.Line>();
    for(PBSI__Quote_Line__c q_l:q_lines) {
        String tax_code = q_l.PBSI__Item__r.PBSI__Item_Group__r.Avatax_Code__c;
        AVA_SF_SDK.TaxSvc.Line t_l = new AVA_SF_SDK.TaxSvc.Line();
        t_l.No = q_l.Name;
        t_l.TaxCode = tax_code;
        if(null!=q_l.PBSI__Item__r && null!=q_l.PBSI__Item__r.Name) t_l.ItemCode = q_l.PBSI__Item__r.Name;
        t_l.Description = q_l.PBSI__Item_SOLine_Description__c;
        t_l.Qty = q_l.PBSI__Quantity__c;
        t_l.Amount = q_l.POS_Line_Subtotal__c;
        tax_rq_lines.add(t_l);
    }
    gtreq.Lines = new AVA_SF_SDK.TaxSvc.ArrayOfLine();
    gtreq.Lines.Line = tax_rq_lines;
    result.put('tax_rq_lines',tax_rq_lines);

    if(0== tax_rq_lines.size()) { // No Quote Lines so 0 tax
        if(0!= q.Total_Sales_Tax_Avatax__c) {
            q.Total_Sales_Tax_Avatax__c = 0;
            q.PBSI__Sales_Tax__c = 0;
            update q;
        }
        result.put('show_tax',true);
        result.put('success',1);
        return result;
    }

    gtreq.DocDate = Date.Today();
    if( null!= tax_sett && 1== tax_sett.size() && tax_sett[0].Auto_Commit__c) 
        gtreq.Commit_x= do_checkout;  // This line is for production
    else
        gtreq.Commit_x= false;  // This line is for the test period

    AVA_SF_SDK.TaxSvc.GetTaxResult gtres = null;
    String tax_calc_res = '';

    Boolean show_tax = false;
    map<String,Decimal> line_2_tax = new map<String,Decimal>();
    try
    {
        if(!cvg_test) gtres = taxSvc.GetTax(gtreq);
        if(null!=gtres && gtres.ResultCode == 'Success')
        {
            result.put('valid',true);
            result.put('total_tax',gtres.TotalTax);
            show_tax = (Boolean)( result.get('valid') ) && null!= gtres && null!= gtres.TaxLines && null!= gtres.TaxLines.TaxLine;
        } else {
            result.put('valid',false);
            if(null!=gtres) { result.put('tax_err_msg_code',gtres.ResultCode); result.put('tax_err_msg_name',gtres.Messages.Message[0].Name); result.put('tax_err_msg_smry',gtres.Messages.Message[0].Summary); }
        }
    }
    catch(Exception ex)
    {
        doErr('GetTax Threw an Exception: ' + ex.getmessage(),'D002',result); return result;
    }

    if(show_tax) {
        for(AVA_SF_SDK.TaxSvc.TaxLine t_l:gtres.TaxLines.TaxLine) line_2_tax.put(t_l.No,100.0*t_l.Rate);
        for(PBSI__Quote_Line__c l:q_lines) {
            if( line_2_tax.get(l.Name) != l.SalesTax_Rate_Avatax__c ) {
                l.SalesTax_Rate_Avatax__c = line_2_tax.get(l.Name);
                upd_q_lines.add(l);
            }
        }
        update upd_q_lines;
        if( q.Total_Sales_Tax_Avatax__c != gtres.TotalTax ) {
            q.Total_Sales_Tax_Avatax__c = gtres.TotalTax;
            if( gtres.TotalAmount > 0 ) q.PBSI__Sales_Tax__c = 100* gtres.TotalTax / gtres.TotalAmount;
            update q;
        }
    }

    result.put('show_tax',show_tax);
    result.put('line_2_tax',line_2_tax);
    result.put('upd_q_lines',upd_q_lines);

    result.put('tax_response',gtres);
    result.put('success',1);
    return result;
}


@RemoteAction
global static Map<String,Object> quote_summ_html(String qt_id) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==qt_id) { doErr('Quote ID must be provided','K001',result); return result; }
    PBSI__Quote__c[] qs = [SELECT Id,Name,CurrencyIsoCode,Quote_Number__c,CreatedDate,POS_Final_Quote_Total__c,POS_Net_Quote_Total__c
        ,PBSI__Sales_Tax__c,Total_Sales_Tax_Avatax__c,Actual_Total_Sales_Tax__c,PBSI__Status__c,PBSI__Account__c,PBSI__Shipping_Cost__c,
        PBSI__Disable_Trade_Agreements__c,PBSI__Trade_Agreement__r.Name 
        FROM PBSI__Quote__c WHERE Id=:qt_id LIMIT 1];

    if(0==qs.size()) { doErr('Quote cannot be found','K002',result); return result; }
    if(null==qs[0].PBSI__Account__c) { doErr('Quote has no Account ID','K003',result); return result; }
    Id acc_id = qs[0].PBSI__Account__c;
    Account acc = [SELECT Id,Name,FirstName,LastName,PersonEmail,Phone,BillingPostalCode,BillingStreet,BillingCity,BillingState,BillingCountry FROM Account WHERE Id=:acc_id LIMIT 1];
    if(null==acc) { doErr('Account not found','K002',result); return result; }
    set<String> bed_IGCs = new set<String>{'GB'};
    PBSI__Quote_Line__c[] q_lines = [SELECT Id,Name,CurrencyIsoCode,CreatedDate,PBSI__Description__c,PBSI__Quantity__c,PBSI__Quote__c,PBSI__Parent_Line__c,PBSI__Item__c,
        PBSI__Item__r.PBSI__Item_Group__r.PBSI__Item_Group_Code__c,PBSI__Item__r.Range_LU__r.Name,PBSI__Item__r.Model_LU__r.Name,
        PBSI__Item__r.Bed_Size__c,PBSI__Item__r.Color__c,PBSI__Item__r.Firmness_Options__c,PBSI__Item__r.Name,
        PBSI__Item__r.PBSI__description__c,
        POS_Discounted_Price__c,POS_Line_Subtotal__c, SalesTax_Rate_Avatax__c,
        Fabric_Colour__c,Firmness__c,VIP_Clips__c,
        Bed_Topper__c,Bed_Topper__r.PBSI__description__c,Bed_Legs__c,Bed_Legs__r.PBSI__description__c,
        Bed_Custom_Size__c, Bed_Custom_Firmness__c, Bed_Custom_Mattress__c, Bed_Custom_Base__c,POS_Item_Spec__c,
        PBSI__Item__r.PBSI__Item_Group__r.Avatax_Code__c, PBSI__Item_SOLine_Description__c
        FROM PBSI__Quote_Line__c WHERE PBSI__Quote__c =:qt_id ORDER BY CreatedDate];
    Id usr_id = UserInfo.getUserId();
    User s_u = [SELECT Id,Name,FirstName,LastName,Email,Phone,PostalCode,Street,City,State,Country,Fax FROM User WHERE Id=:usr_id LIMIT 1];
    set<Id> vip_clip_ids = new set<Id>();
    for(PBSI__PBSI_Item_Group__c vc:[SELECT Id,VIP_Clips_for_this_Item_Group__c FROM PBSI__PBSI_Item_Group__c WHERE VIP_Clips_for_this_Item_Group__c != null]) vip_clip_ids.add(vc.VIP_Clips_for_this_Item_Group__c);

// -- dtls_table    Quote ID & Customer 
    String ref_div = o_fmt_line1('qut-name','Quote',qs[0].Name);
    String dtls_table = '<table class="q_dtls_table"><tr class="q_dtls_h">'
        + o_fmt_col_1('col1','Your Quote')
        + o_fmt_col_1('col2','Customer')
        + o_fmt_col_1('col3','Address')
        +'</tr><tr class="q_dtls_vals">' 
        + o_fmt_col_2('ref_div_content text1',ref_div)
        + o_fmt_col_2('o_cust_ctct_ro text1',o_fmt_ctct_1(acc))
        + o_fmt_col_2('o_cust_addr_ro text1',o_fmt_addr_1(acc))
        +'</tr></table>';

// -- bed_list_tbl    Quote ID & Customer
    set<Id> q_lines_4_beds = new set<Id>();
    String[] bedHTs = new List<String>();
    for(Integer i=0; i<q_lines.size(); i++) {
        PBSI__Quote_Line__c q_l = q_lines[i];
        if(null!=q_l.PBSI__Item__r && null!=q_l.PBSI__Item__r.PBSI__Item_Group__r && bed_IGCs.contains(q_l.PBSI__Item__r.PBSI__Item_Group__r.PBSI__Item_Group_Code__c)) {
            q_lines_4_beds.add(q_l.Id);
            String[] baHT = new List<String>();
            baHT.add('<tr class="bed_spec_tr" ql_id="'+q_l.Id+'">');
            baHT.add(o_fmt_bed_GBed_quot('bed_summ_spec',q_l));
            baHT.add(o_fmt_col_i_nval1('bed_summ_qty_col','bed_summ_qty',q_l.Id,q_l.PBSI__Quantity__c));
            baHT.add(o_fmt_col_cval1('bed_summ_price',q_l.CurrencyIsoCode,q_l.POS_Discounted_Price__c));
            baHT.add(o_fmt_col_i_pval1('bed_summ_tax',q_l.Id,q_l.SalesTax_Rate_Avatax__c));
            baHT.add(o_fmt_col_cval1('bed_summ_line_tot',q_l.CurrencyIsoCode,q_l.POS_Line_Subtotal__c));
            baHT.add('</tr>');
            bedHTs.add( String.join(baHT, '') );

            PBSI__Quote_Line__c[] legs_lines = new list<PBSI__Quote_Line__c>();
            PBSI__Quote_Line__c[] clips_lines = new list<PBSI__Quote_Line__c>();
            for(PBSI__Quote_Line__c q_l2:q_lines) {
                if( q_l2.PBSI__Parent_Line__c == q_l.Id ) {
                    if( vip_clip_ids.contains(q_l2.PBSI__Item__c) ) clips_lines.add(q_l2);
                    else legs_lines.add(q_l2);
                }
            }
            for(PBSI__Quote_Line__c legs_line:legs_lines) {
                q_lines_4_beds.add(legs_line.Id);
                baHT = new List<String>();
                baHT.add('<tr class="bed_spec_tr">');
                baHT.add(o_fmt_bed_part_1('bed_summ_spec',legs_line.PBSI__Item__r));
                baHT.add(o_fmt_col_i_nval2('bed_part_qty_col','bed_summ_qty',legs_line.Id,legs_line.PBSI__Quantity__c));
                baHT.add(o_fmt_col_cval1('bed_summ_price',legs_line.CurrencyIsoCode,legs_line.POS_Discounted_Price__c));
                baHT.add(o_fmt_col_pval1('bed_summ_tax',q_l.SalesTax_Rate_Avatax__c));
                baHT.add(o_fmt_col_cval1('bed_summ_line_tot',legs_line.CurrencyIsoCode,legs_line.POS_Line_Subtotal__c));
                baHT.add('</tr>');
                bedHTs.add( String.join(baHT, '') );
            }
            for(PBSI__Quote_Line__c clips_line:clips_lines) {
                q_lines_4_beds.add(clips_line.Id);
                baHT = new List<String>();
                baHT.add('<tr class="bed_spec_tr">');
                baHT.add(o_fmt_bed_part_1('bed_summ_spec',clips_line.PBSI__Item__r));
                baHT.add(o_fmt_col_i_nval2('bed_part_qty_col','bed_summ_qty',clips_line.Id,clips_line.PBSI__Quantity__c));
                baHT.add(o_fmt_col_cval1('bed_summ_price',clips_line.CurrencyIsoCode,clips_line.POS_Discounted_Price__c));
                baHT.add(o_fmt_col_pval1('bed_summ_tax',q_l.SalesTax_Rate_Avatax__c));
                baHT.add(o_fmt_col_cval1('bed_summ_line_tot',clips_line.CurrencyIsoCode,clips_line.POS_Line_Subtotal__c));
                baHT.add('</tr>');
                bedHTs.add( String.join(baHT, '') );
            }

        }
    }
    String bed_list_rows = String.join(bedHTs, '');
    String bed_list_tbl = '<table class="q_bed_list_table"><tr class="q_bed_list_h">'
        + o_fmt_col_1('col1','Beds')
        + o_fmt_col_1('col2','Qty')
        + o_fmt_col_1('col3','Price')
        + o_fmt_col_1('col4','Sales Tax')
        + o_fmt_col_1('col5','Line Total')
        +'</tr>' + bed_list_rows +'</table>';
    if(bed_list_rows=='') bed_list_tbl = '';

// -- accy_list_tbl    Quote ID & Customer  
    String[] accyHTs = new List<String>();
    for(Integer i=0; i<q_lines.size(); i++) {
        PBSI__Quote_Line__c q_l = q_lines[i];
        if( !q_lines_4_beds.contains(q_l.Id) ) {
            String[] baHT = new List<String>();
            baHT.add('<tr class="bed_spec_tr" ql_id="'+q_l.Id+'">');
            if( null!=q_l.PBSI__Item__r && null!=q_l.PBSI__Item__r.PBSI__Item_Group__r)
                baHT.add(o_fmt_accy_1('bed_summ_spec',q_l.PBSI__Item__r,q_l.PBSI__Description__c));
            else
                baHT.add(o_fmt_unkn_1('bed_summ_spec'));
            baHT.add(o_fmt_col_i_nval1('bed_summ_qty_col','bed_summ_qty',q_l.Id,q_l.PBSI__Quantity__c));
            baHT.add(o_fmt_col_cval1('bed_summ_price',q_l.CurrencyIsoCode,q_l.POS_Discounted_Price__c));
            baHT.add(o_fmt_col_i_pval1('bed_summ_tax',q_l.Id,q_l.SalesTax_Rate_Avatax__c));
            baHT.add(o_fmt_col_cval1('bed_summ_line_tot',q_l.CurrencyIsoCode,q_l.POS_Line_Subtotal__c));
            baHT.add('</tr>');
            accyHTs.add( String.join(baHT, '') );
        }
    }
    String accy_list_rows = String.join(accyHTs, '');
    String accy_list_tbl = '<table class="q_bed_list_table"><tr class="q_bed_list_h">'
        + o_fmt_col_1('col1','Accessories')
        + o_fmt_col_1('col2','Qty')
        + o_fmt_col_1('col3','Price')
        + o_fmt_col_1('col4','Sales Tax')
        + o_fmt_col_1('col5','Line Total')
        +'</tr>' + accy_list_rows +'</table>';
    if(accy_list_rows=='') accy_list_tbl = '';

// -- summ_table    
    Decimal net_tot = (null== qs[0].POS_Net_Quote_Total__c) ? 0 : qs[0].POS_Net_Quote_Total__c;
    Decimal final_tot = (null== qs[0].POS_Final_Quote_Total__c) ? 0 : qs[0].POS_Final_Quote_Total__c;
    Decimal sl_tax = (null== qs[0].Actual_Total_Sales_Tax__c) ? 0 : qs[0].Actual_Total_Sales_Tax__c;
    Decimal ship_tot = (null== qs[0].PBSI__Shipping_Cost__c) ? 0 : qs[0].PBSI__Shipping_Cost__c;
    String trd_agr = (qs[0].PBSI__Disable_Trade_Agreements__c
                    || null == qs[0].PBSI__Trade_Agreement__r.Name
                    || '' == qs[0].PBSI__Trade_Agreement__r.Name
                    ? '' : qs[0].PBSI__Trade_Agreement__r.Name + ' Applied' );
    String summ_table = '<table class="q_sum_table"><tr class="q_sum_h">'
        + o_fmt_col_1('col1','')
        + o_fmt_col_1('col2','Net')
        + o_fmt_col_1('col3','Sales Tax')
        + o_fmt_col_1('col4','Shipping')
        + o_fmt_col_1('col4','Total')
        +'</tr><tr class="q_sum_vals">' 
        + o_fmt_col_1('col1','<span class="ql-lbl"></span><span class="ql-val">' + trd_agr + '</span>')
        + o_fmt_col_cval1('col2 ord_summ_net_tot',qs[0].CurrencyIsoCode,net_tot)
        + o_fmt_col_cval1('col3 ord_summ_tax_tot',qs[0].CurrencyIsoCode,sl_tax)
        + o_fmt_col_edit_cval1('col4 ord_summ_ship_tot',qs[0].CurrencyIsoCode,ship_tot)
        + o_fmt_col_cval1('col4 ord_summ_fin_tot',qs[0].CurrencyIsoCode,final_tot)
        +'</tr></table>';

    String order_html = dtls_table + bed_list_tbl + accy_list_tbl + summ_table;

    Map<Id,PBSI__Quote_Line__c> q_l_specs = new Map<Id,PBSI__Quote_Line__c>();
    for(PBSI__Quote_Line__c q_l:q_lines) q_l_specs.put(q_l.Id,q_l);

    result.put('account',acc);
    result.put('user',s_u);
    result.put('quote',qs[0]);
//    result.put('q_lines',q_lines);
    result.put('q_l_specs',q_l_specs);
    result.put('order_html',order_html);
    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> order_summ_html(String o_id) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==o_id) { doErr('Quote ID must be provided','K001',result); return result; }
    PBSI__PBSI_Sales_Order__c[] qs = [SELECT Id,Name,CurrencyIsoCode,CreatedDate,Net_Order_Total_From_Quote__c,Final_Order_Total_From_Quote__c,Sales_Tax_Total_From_Quote__c,VAT__c,
        Paid_Amount__c,PBSI__Status__c,PBSI__Customer__c,Region__c,PBSI__Shipping_Cost__c,
        PBSI__Disable_Sales_Trade_Agreement__c,PBSI__Trade_Agreement__r.Name  
        FROM PBSI__PBSI_Sales_Order__c WHERE Id=:o_id LIMIT 1];

    if(0==qs.size()) { doErr('Quote cannot be found','K002',result); return result; }
    if(null==qs[0].PBSI__Customer__c) { doErr('Quote has no Account ID','K003',result); return result; }
    Id acc_id = qs[0].PBSI__Customer__c;
    Account acc = [SELECT Id,Name,FirstName,LastName,PersonEmail,Phone,BillingPostalCode,BillingStreet,BillingCity,BillingState,BillingCountry FROM Account WHERE Id=:acc_id LIMIT 1];
    if(null==acc) { doErr('Account not found','K002',result); return result; }


    set<String> bed_IGCs = new set<String>{'GB'};
    PBSI__PBSI_Sales_Order_Line__c[] q_lines = [SELECT Id,Name,CurrencyIsoCode,CreatedDate,PBSI__ItemDescription__c,PBSI__Quantity_Needed__c,PBSI__Sales_Order__c,PBSI__Parent_Line__c,PBSI__Item__c,
        PBSI__Item__r.PBSI__Item_Group__r.PBSI__Item_Group_Code__c,PBSI__Item__r.Range_LU__r.Name,PBSI__Item__r.Model_LU__r.Name,
        PBSI__Item__r.Bed_Size__c,PBSI__Item__r.Color__c,PBSI__Item__r.Firmness_Options__c,PBSI__Item__r.Name,
        PBSI__Item__r.PBSI__description__c,
        PBSI__Price__c,PBSI__Total_Price__c,Sale_Price_From_Quote__c,PBSI__Tax__c,Line_Total_From_Quote__c,
        Fabric_Colour__c,Firmness__c,VIP_Clips__c,
        Bed_Topper__c,Bed_Topper__r.Name,Bed_Legs__c,Bed_Legs__r.PBSI__description__c,
        Bed_Custom_Size__c, Bed_Custom_Firmness__c, Bed_Custom_Mattress__c, Bed_Custom_Base__c
        FROM PBSI__PBSI_Sales_Order_Line__c WHERE PBSI__Sales_Order__c =:o_id];
    Id usr_id = UserInfo.getUserId();
    User s_u = [SELECT Id,Name,FirstName,LastName,Email,Phone,PostalCode,Street,City,State,Country,Fax FROM User WHERE Id=:usr_id LIMIT 1];
    set<Id> vip_clip_ids = new set<Id>();
    for(PBSI__PBSI_Item_Group__c vc:[SELECT Id,VIP_Clips_for_this_Item_Group__c FROM PBSI__PBSI_Item_Group__c WHERE VIP_Clips_for_this_Item_Group__c != null]) vip_clip_ids.add(vc.VIP_Clips_for_this_Item_Group__c);


// -- dtls_table    Quote ID & Customer 
    String ref_div = o_fmt_line1('qut-name','Our Ref',qs[0].Name);
    String dtls_table = '<table class="q_dtls_table"><tr class="q_dtls_h">'
        + o_fmt_col_1('col1','Your Order')
        + o_fmt_col_1('col2','Customer')
        + o_fmt_col_1('col3','Address')
        +'</tr><tr class="q_dtls_vals">' 
        + o_fmt_col_2('ref_div_content text1',ref_div)
        + o_fmt_col_2('o_cust_ctct_ro text1',o_fmt_ctct_1(acc))
        + o_fmt_col_2('o_cust_addr_ro text1',o_fmt_addr_1(acc))
        +'</tr></table>';

// -- bed_list_tbl    Quote ID & Customer   
    set<Id> q_lines_4_beds = new set<Id>();
    String[] bedHTs = new List<String>();
    for(Integer i=0; i<q_lines.size(); i++) {
        PBSI__PBSI_Sales_Order_Line__c q_l = q_lines[i];
        if(null!=q_l.PBSI__Item__r && null!=q_l.PBSI__Item__r.PBSI__Item_Group__r && bed_IGCs.contains(q_l.PBSI__Item__r.PBSI__Item_Group__r.PBSI__Item_Group_Code__c)) {
            q_lines_4_beds.add(q_l.Id);
            String[] baHT = new List<String>();
            baHT.add('<tr class="bed_spec_tr">');
            if('GB'==q_l.PBSI__Item__r.PBSI__Item_Group__r.PBSI__Item_Group_Code__c)
                baHT.add(o_fmt_bed_GBed_ord('bed_summ_spec',q_l));
            else
                baHT.add(o_fmt_bed_Bed_ord('bed_summ_spec',q_l));
            baHT.add(o_fmt_col_i_nval2('bed_summ_qty_col','bed_summ_qty',q_l.Id,q_l.PBSI__Quantity_Needed__c.intValue()));
            baHT.add(o_fmt_col_cval1('bed_summ_price',q_l.CurrencyIsoCode,q_l.Sale_Price_From_Quote__c));
            baHT.add(o_fmt_col_pval1('bed_summ_tax',q_l.PBSI__Tax__c));
            baHT.add(o_fmt_col_cval1('bed_summ_line_tot',q_l.CurrencyIsoCode,q_l.Line_Total_From_Quote__c));
            baHT.add('</tr>');
            bedHTs.add( String.join(baHT, '') );

            PBSI__PBSI_Sales_Order_Line__c[] legs_lines = new list<PBSI__PBSI_Sales_Order_Line__c>();
            PBSI__PBSI_Sales_Order_Line__c[] clips_lines = new list<PBSI__PBSI_Sales_Order_Line__c>();
            for(PBSI__PBSI_Sales_Order_Line__c q_l2:q_lines) {
                if( q_l2.PBSI__Parent_Line__c == q_l.Id ) {
                    if( vip_clip_ids.contains(q_l2.PBSI__Item__c) ) clips_lines.add(q_l2);
                    else legs_lines.add(q_l2);
                }
            }
            for(PBSI__PBSI_Sales_Order_Line__c legs_line:legs_lines) {
                q_lines_4_beds.add(legs_line.Id);
                baHT = new List<String>();
                baHT.add('<tr class="bed_spec_tr">');
                baHT.add(o_fmt_bed_part_1('bed_summ_spec',legs_line.PBSI__Item__r));
                baHT.add(o_fmt_col_i_nval2('bed_summ_qty_col','bed_summ_qty',legs_line.Id,legs_line.PBSI__Quantity_Needed__c.intValue()));
                baHT.add(o_fmt_col_cval1('bed_summ_price',legs_line.CurrencyIsoCode,legs_line.Sale_Price_From_Quote__c));
                baHT.add(o_fmt_col_pval1('bed_summ_tax',legs_line.PBSI__Tax__c));
                baHT.add(o_fmt_col_cval1('bed_summ_line_tot',legs_line.CurrencyIsoCode,legs_line.Line_Total_From_Quote__c));
                baHT.add('</tr>');
                bedHTs.add( String.join(baHT, '') );
            }
            for(PBSI__PBSI_Sales_Order_Line__c clips_line:clips_lines) {
                q_lines_4_beds.add(clips_line.Id);
                baHT = new List<String>();
                baHT.add('<tr class="bed_spec_tr">');
                baHT.add(o_fmt_bed_part_1('bed_summ_spec',clips_line.PBSI__Item__r));
                baHT.add(o_fmt_col_i_nval2('bed_summ_qty_col','bed_summ_qty',clips_line.Id,clips_line.PBSI__Quantity_Needed__c.intValue()));
                baHT.add(o_fmt_col_cval1('bed_summ_price',clips_line.CurrencyIsoCode,clips_line.Sale_Price_From_Quote__c));
                baHT.add(o_fmt_col_pval1('bed_summ_tax',clips_line.PBSI__Tax__c));
                baHT.add(o_fmt_col_cval1('bed_summ_line_tot',clips_line.CurrencyIsoCode,clips_line.Line_Total_From_Quote__c));
                baHT.add('</tr>');
                bedHTs.add( String.join(baHT, '') );
            }

        }
    }

    String bed_list_rows = String.join(bedHTs, '');
    String bed_list_tbl = '<table class="q_bed_list_table"><tr class="q_bed_list_h">'
        + o_fmt_col_1('col1','Beds')
        + o_fmt_col_1('col2','Qty')
        + o_fmt_col_1('col3','Price')
        + o_fmt_col_1('col4','Sales Tax')
        + o_fmt_col_1('col5','Line Total')
        +'</tr>' + bed_list_rows +'</table>';
    if(bed_list_rows=='') bed_list_tbl = '';

// -- accy_list_tbl    Quote ID & Customer  
    String[] accyHTs = new List<String>();
    for(Integer i=0; i<q_lines.size(); i++) {
        PBSI__PBSI_Sales_Order_Line__c q_l = q_lines[i];
        if(!q_lines_4_beds.contains(q_l.Id)) {
            String[] baHT = new List<String>();
            baHT.add('<tr class="bed_spec_tr">');
            if( null!=q_l.PBSI__Item__r && null!=q_l.PBSI__Item__r.PBSI__Item_Group__r)
                baHT.add(o_fmt_accy_1('bed_summ_spec',q_l.PBSI__Item__r,q_l.PBSI__ItemDescription__c));
            else
                baHT.add(o_fmt_unkn_1('bed_summ_spec'));
            baHT.add(o_fmt_col_i_nval2('bed_summ_qty_col','bed_summ_qty',q_l.Id,q_l.PBSI__Quantity_Needed__c.intValue()));
            baHT.add(o_fmt_col_cval1('bed_summ_price',q_l.CurrencyIsoCode,q_l.Sale_Price_From_Quote__c));
            baHT.add(o_fmt_col_pval1('bed_summ_tax',q_l.PBSI__Tax__c));
            baHT.add(o_fmt_col_cval1('bed_summ_line_tot',q_l.CurrencyIsoCode,q_l.Line_Total_From_Quote__c));
            baHT.add('</tr>');
            accyHTs.add( String.join(baHT, '') );
        }
    }

    String accy_list_rows = String.join(accyHTs, '');
    String accy_list_tbl = '<table class="q_bed_list_table"><tr class="q_bed_list_h">'
        + o_fmt_col_1('col1','Accessories')
        + o_fmt_col_1('col2','Qty')
        + o_fmt_col_1('col3','Price')
        + o_fmt_col_1('col4','Sales Tax')
        + o_fmt_col_1('col5','Line Total')
        +'</tr>' + accy_list_rows +'</table>';
    if(accy_list_rows=='') accy_list_tbl = '';
    
// -- summ_table    
    Decimal sl_tax = (null== qs[0].Sales_Tax_Total_From_Quote__c) ? 0 : qs[0].Sales_Tax_Total_From_Quote__c;
    Decimal net_tot = (null== qs[0].Net_Order_Total_From_Quote__c) ? 0 : qs[0].Net_Order_Total_From_Quote__c;
    Decimal ship_tot = (null== qs[0].PBSI__Shipping_Cost__c) ? 0 : qs[0].PBSI__Shipping_Cost__c;
    Decimal final_tot = (null== qs[0].Final_Order_Total_From_Quote__c) ? 0 : qs[0].Final_Order_Total_From_Quote__c;
    String trd_agr = (qs[0].PBSI__Disable_Sales_Trade_Agreement__c
                    || null == qs[0].PBSI__Trade_Agreement__r.Name
                    || '' == qs[0].PBSI__Trade_Agreement__r.Name
                    ? '' : qs[0].PBSI__Trade_Agreement__r.Name + ' Applied' );
    String summ_table = '<table class="q_sum_table"><tr class="q_sum_h">'
        + o_fmt_col_1('col1','')
        + o_fmt_col_1('col2','Net')
        + o_fmt_col_1('col3','Sales Tax')
        + o_fmt_col_1('col4','Shipping')
        + o_fmt_col_1('col4','Total')
        +'</tr><tr class="q_sum_vals">' 
        + o_fmt_col_1('col1','')
        + o_fmt_col_cval1('col2 ord_summ_net_tot',qs[0].CurrencyIsoCode,net_tot)
        + o_fmt_col_cval1('col3 ord_summ_tax_tot',qs[0].CurrencyIsoCode,sl_tax)
        + o_fmt_col_edit_cval1('col4 ord_summ_ship_tot',qs[0].CurrencyIsoCode,ship_tot)
        + o_fmt_col_cval1('col4 ord_summ_fin_tot',qs[0].CurrencyIsoCode,final_tot)
        +'</tr></table>';

    Decimal paid = (null== qs[0].Paid_Amount__c) ? 0 : qs[0].Paid_Amount__c;
    Decimal o_balance = final_tot - paid;
    String pay_table = '<table class="q_paid_table"><tr class="q_sum_h">'
        + o_fmt_col_1('col1','')
        + o_fmt_col_1('col2','Paid')
        + o_fmt_col_1('col3','Balance to Pay')
        +'</tr><tr class="q_sum_vals">' 
        + o_fmt_col_1('col1','<span class="ql-lbl"></span><span class="ql-val">' + trd_agr + '</span>')
        + o_fmt_col_cval1('col2 ord_summ_paid_tot',qs[0].CurrencyIsoCode,paid)
        + o_fmt_col_cval1('col3 ord_summ_fin_tot',qs[0].CurrencyIsoCode,o_balance)
        +'</tr></table>';

    String order_html = dtls_table + bed_list_tbl + accy_list_tbl + summ_table + pay_table;

    result.put('account',acc);
    result.put('user',s_u);
    result.put('order',qs[0]);
    result.put('o_lines',q_lines);
    result.put('o_balance',o_balance);
    result.put('order_html',order_html);
    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> new_quote(String acc_id) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==acc_id) { doErr('Account ID must be provided','K001',result); return result; }
    Account acc = [SELECT Id,Name FROM Account WHERE Id=:acc_id LIMIT 1];
    if(null==acc) { doErr('Account not found','K002',result); return result; }
    String q_name = 'Quote for '+acc.Name+' ['+ Datetime.now().format('yyyy/MM/dd HH:mm') +']';
    PBSI__Quote__c quote = new PBSI__Quote__c(Name=q_name,PBSI__Account__c=acc_id,PBSI__Status__c='Active');
    insert quote;
    result.put('quote',quote);
    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> del_bed_line(String q_id,Map<String,String> bed) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==q_id) { doErr('Quote ID must be provided','K001',result); return result; }
    if(null==bed) { doErr('Bed details must be provided','K002',result); return result; }
    PBSI__Quote_Line__c q_l;    
    if(null!=bed.get('ql_id')) {
        String ql_id = bed.get('ql_id');
        PBSI__Quote_Line__c[] q_lines = [SELECT Id,Name,PBSI__Quote__c FROM PBSI__Quote_Line__c WHERE Id=:ql_id LIMIT 1];
        if(q_lines.size() >0) q_l = q_lines[0];
        else { doErr('Quote line didnt exist','K003',result); return result; }
    } else { doErr('Quote Line ID must be provided','K004',result); return result; }

    PBSI__Quote_Line__c[] q_sub_lines;
    if(null!=q_l) {
        q_sub_lines = [SELECT Id,Name,PBSI__Quote__c FROM PBSI__Quote_Line__c WHERE PBSI__Parent_Line__c=:q_l.Id];
        if(q_sub_lines.size() >0) {
            try {
                delete q_sub_lines;
            } catch (Exception e) {
                if(null==bed) { doErr('Couldnt delete quote sub lines: '+e.getMessage(),'D001',result); return result; }
            }
        }
    } 

    try {
        delete q_l;
    } catch (Exception e) {
        if(null==bed) { doErr('Couldnt delete quote line: '+e.getMessage(),'D002',result); return result; }
    }

    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> upsert_bed_line(String q_id,Map<String,String> bed) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==q_id) { doErr('Quote ID must be provided','K001',result); return result; }
    if(null==bed) { doErr('Bed details must be provided','K002',result); return result; }

    Integer bed_q = 1;
    if(null!= bed.get('bed_qty')) bed_q = integer.valueOf( bed.get('bed_qty') );
    PBSI__Quote_Line__c q_l;    
    if(null!=bed.get('ql_id')) {
        String ql_id = bed.get('ql_id');
        PBSI__Quote_Line__c[] q_lines = [SELECT Id,Name,PBSI__Quote__c,PBSI__Item__c,Fabric_Colour__c,Firmness__c,Bed_Topper__c,Bed_Legs__c,VIP_Clips__c FROM PBSI__Quote_Line__c WHERE Id=:ql_id LIMIT 1];
        if(q_lines.size() >0) q_l = q_lines[0];
    }
    if(null==q_l) q_l = new PBSI__Quote_Line__c(PBSI__Quote__c=q_id);
//  if(null!= bed.get('bed_range_IGC')) q_l.Bed_Range__c = bed.get('bed_range_IGC');
//  if(null!= bed.get('model_id')) q_l.Bed_Model__c = bed.get('model_id');
//  if(null!= bed.get('bed_size')) q_l.Bed_Size__c = bed.get('bed_size');
    q_l.POS_Item_Spec__c = JSON.serialize(bed);
//  q_l.PBSI__Quantity__c = bed_q;
    q_l.PBSI__Quantity__c = 0;
    if(null!= bed.get('bed_color')) q_l.Fabric_Colour__c = bed.get('bed_color');
    if(null!= bed.get('bed_firmness')) q_l.Firmness__c = bed.get('bed_firmness');
    if(null!= bed.get('topm_id')) q_l.Bed_Topper__c = bed.get('topm_id');
    if(null!= bed.get('item_id')) q_l.PBSI__Item__c = bed.get('item_id');
    if(null!= bed.get('vip_clips')) q_l.VIP_Clips__c = ('true' == bed.get('vip_clips') ? true : false);
    if(null!= bed.get('legs_id')) q_l.Bed_Legs__c = bed.get('legs_id');
    if(null!= bed.get('bed_cust_size')) {
        q_l.PBSI__Discount__c = -20;
        q_l.Bed_Custom_Size__c = bed.get('bed_cust_size');
    }
    if(null!= bed.get('bed_base_split')) q_l.Bed_Custom_Base__c = bed.get('bed_base_split');
    if(null!= bed.get('bed_mattr_split')) q_l.Bed_Custom_Mattress__c = bed.get('bed_mattr_split');


// Lookup related records
    PBSI__PBSI_Item__c bed_model = [SELECT Id
        ,Model_LU__r.VIP_Clips_for_this_Item_Group__c
        ,Model_LU__r.Nameplates_for_this_item_group__c
        ,Model_LU__r.Leg_Options_Models_Only__c
        ,Model_LU__r.Split_Base_and_Mattress_Charge__c
         FROM PBSI__PBSI_Item__c WHERE Id=:q_l.PBSI__Item__c LIMIT 1];

    PBSI__PBSI_Item__c vip_clip_item;
    PBSI__PBSI_Item__c nameplates_item;
    PBSI__PBSI_Item__c specials_fee_item;
    if(null== bed_model) {
        doErr('Couldnt update quote line. Obsolete item selection.','D003',result); return result;
    } 

    Id vip_clip_id = bed_model.Model_LU__r.VIP_Clips_for_this_Item_Group__c;
    if( null!= vip_clip_id ) for(PBSI__PBSI_Item__c vc:[SELECT Id FROM PBSI__PBSI_Item__c WHERE Id=:vip_clip_id LIMIT 1]) vip_clip_item=vc;
    
    Id nameplates_id = bed_model.Model_LU__r.Nameplates_for_this_item_group__c;
    if( null!= nameplates_id ) for(PBSI__PBSI_Item__c n:[SELECT Id FROM PBSI__PBSI_Item__c WHERE Id=:nameplates_id LIMIT 1]) nameplates_item=n;

    Id specials_fee_id = bed_model.Model_LU__r.Split_Base_and_Mattress_Charge__c;
    if( null!= specials_fee_id ) for(PBSI__PBSI_Item__c itm:[SELECT Id FROM PBSI__PBSI_Item__c WHERE Id=:specials_fee_id LIMIT 1]) specials_fee_item=itm;

// Created or update main quote line
    try {
        upsert q_l;
    } catch (Exception e) {
        if(null==bed) { doErr('Couldnt update quote line: '+e.getMessage(),'D001',result); return result; }
    }
    q_l.PBSI__Quantity__c = bed_q;
    try {
        upsert q_l;
    } catch (Exception e) {
        if(null==bed) { doErr('Couldnt update quote line: '+e.getMessage(),'D001',result); return result; }
    }

// Delete related records

    PBSI__Quote_Line__c[] q_rel_lines = [SELECT Id FROM PBSI__Quote_Line__c WHERE PBSI__Parent_Line__c=:q_l.Id];
    try {
        delete q_rel_lines;
    } catch (Exception e) {
        if(null==bed) { doErr('Couldnt delete related quote lines: '+e.getMessage(),'D004',result); return result; }
    }


// Create related records
    PBSI__Quote_Line__c q_legs_l; 
    if( null!= bed.get('legs_id') && null!=q_l.Id ) {
        q_legs_l = new PBSI__Quote_Line__c( 
            PBSI__Quote__c=q_id
            ,PBSI__Parent_Line__c= q_l.Id
            ,PBSI__Item__c = bed.get('legs_id')
            ,PBSI__Quantity__c = 0 
        );
        try {
            insert q_legs_l;
        } catch (Exception e) {
            if(null==bed) { doErr('Couldnt update quote line: '+e.getMessage(),'D001',result); return result; }
        }
        q_legs_l.PBSI__Quantity__c = ( null== bed.get('legs_n') ? bed_q : bed_q * integer.valueOf(bed.get('legs_n')) );
        try {
            upsert q_legs_l;
        } catch (Exception e) {
            if(null==bed) { doErr('Couldnt update quote line: '+e.getMessage(),'D001',result); return result; }
        }
    }

    PBSI__Quote_Line__c q_vc_l; 
    if( q_l.VIP_Clips__c && null!=vip_clip_item && null!=q_l.Id ) {

        q_vc_l = new PBSI__Quote_Line__c(
            PBSI__Quote__c = q_id
            ,PBSI__Parent_Line__c = q_l.Id
            ,PBSI__Item__c = vip_clip_item.Id
            ,PBSI__Quantity__c = 0
        );
        try {
            insert q_vc_l;
        } catch (Exception e) {
            doErr('Couldnt update quote line: '+e.getMessage(),'D002',result); return result;
        }
        q_vc_l.PBSI__Quantity__c = bed_q;
        try {
            upsert q_vc_l;
        } catch (Exception e) {
            doErr('Couldnt update quote line: '+e.getMessage(),'D002',result); return result;
        }
    }
    
    PBSI__Quote_Line__c q_nameplates_l; 
    if('true' == bed.get('nameplates') && null!=nameplates_item && null!=q_l.Id ) {

        q_nameplates_l = new PBSI__Quote_Line__c(
            PBSI__Quote__c = q_id
            ,PBSI__Parent_Line__c = q_l.Id
            ,PBSI__Item__c = nameplates_item.Id
            ,PBSI__Quantity__c = 0
        );
        try {
            insert q_nameplates_l;
        } catch (Exception e) {
            doErr('Couldnt update quote line: '+e.getMessage(),'D002',result); return result;
        }
        q_nameplates_l.PBSI__Quantity__c = bed_q;
        try {
            upsert q_nameplates_l;
        } catch (Exception e) {
            doErr('Couldnt update quote line: '+e.getMessage(),'D002',result); return result;
        }
    }

    PBSI__Quote_Line__c q_spc_fee_l;
    Boolean spcl_bed = null!=q_l.Firmness__c && -1 != q_l.Firmness__c.indexOf('/');

    if( null!=q_l.Id && spcl_bed && null!=specials_fee_item ) {

        q_spc_fee_l = new PBSI__Quote_Line__c(
            PBSI__Quote__c = q_id
            ,PBSI__Parent_Line__c = q_l.Id
            ,PBSI__Item__c = specials_fee_item.Id
            ,PBSI__Quantity__c = 0
        );
        try {
            insert q_spc_fee_l;
        } catch (Exception e) {
            doErr('Couldnt update quote line: '+e.getMessage(),'D005',result); return result;
        }
        q_spc_fee_l.PBSI__Quantity__c = bed_q;
        try {
            upsert q_spc_fee_l;
        } catch (Exception e) {
            doErr('Couldnt update quote line: '+e.getMessage(),'D005',result); return result;
        }
    }


    result.put('q_l',q_l);
    result.put('q_legs_l',q_legs_l);
    result.put('q_vc_l',q_vc_l);
    result.put('v_c',vip_clip_item);
    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> upsert_accy_line(String q_id,Map<String,String> accy_spec) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==q_id) { doErr('Quote ID must be provided','K001',result); return result; }
    if(null==accy_spec) { doErr('Accessory spec must be provided','K004',result); return result; }
    if(null==accy_spec.get('item_id')) { doErr('Accessory Item Id must be specified','K003',result); return result; }

    Integer accy_q = 1;
    if(null!= accy_spec.get('accy_qty')) accy_q = integer.valueOf( accy_spec.get('accy_qty') );

    PBSI__Quote_Line__c q_l;    
    if(null!=accy_spec.get('ql_id')) {
        String ql_id = accy_spec.get('ql_id');
        PBSI__Quote_Line__c[] q_lines = [SELECT Id,Name,PBSI__Quote__c,PBSI__Item__c FROM PBSI__Quote_Line__c WHERE Id=:ql_id LIMIT 1];
        if(q_lines.size() >0) q_l = q_lines[0];
    }
    if(null==q_l) q_l = new PBSI__Quote_Line__c(PBSI__Quote__c=q_id);
    q_l.POS_Item_Spec__c = JSON.serialize(accy_spec);
    q_l.PBSI__Quantity__c = accy_q;
    q_l.PBSI__Item__c = accy_spec.get('item_id');

    try {
        upsert q_l;
    } catch (Exception e) {
        doErr('Couldnt update quote line: '+e.getMessage(),'D001',result); return result;
    }

    result.put('q_l',q_l);
    result.put('success',1);
    return result;
}
@RemoteAction
global static Map<String,Object> upd_ql_qty(String ql_id,Integer qty) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();
    if(null==ql_id) { doErr('Quote Line ID must be provided','K001',result); return result; }
    PBSI__Quote_Line__c q_l;
    PBSI__Quote_Line__c[] q_lines = [SELECT Id,Name,PBSI__Quote__c,PBSI__Item__c,PBSI__Quantity__c FROM PBSI__Quote_Line__c WHERE Id=:ql_id LIMIT 1];
    if(q_lines.size() ==0) { doErr('A valid Quote line must be identified','K002',result); return result; }
    q_l = q_lines[0];
    if(qty>0) {
        q_l.PBSI__Quantity__c = qty;
        upsert q_l;
    } else {
        delete q_l;
    }
    result.put('q_l',q_l);
    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> list_bed_options(Map<String,String> bed_dtls) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();
    List<PBSI__PBSI_Item__c> bed_matches = new List<PBSI__PBSI_Item__c>();

    if(null==bed_dtls) { doErr('Bed details must be provided','K001',result); return result; }
    if(null==bed_dtls.get('bed_range')) { doErr('Bed range must be provided','K002',result); return result; }

    Map<String,Integer> size_o = new Map<String,Integer>();
//    Map<String,Integer> firmness_o = new Map<String,Integer>();
    List<PBSI__Configuration_Item__c> leg_o = null;
    List<PBSI__Configuration_Item__c> topper_o = null;

    List<PBSI__PBSI_Item_Group__c> model_o = new List<PBSI__PBSI_Item_Group__c>( [SELECT Id,Name,Leg_Options_Models_Only__c,Mattress_Topper_Options_Model_Only__c,VIP_Clips_for_this_Item_Group__c, Nameplates_for_this_item_group__c, Color_Exclusions_For_This_Model__c FROM PBSI__PBSI_Item_Group__c WHERE PBSI__Parent_Group__r.PBSI__Item_Group_Code__c=:bed_dtls.get('bed_range_IGC') ORDER BY POS_Selector_Rank__c,Name] );
    Map<Id,PBSI__PBSI_Item_Group__c> model_map = new Map<Id,PBSI__PBSI_Item_Group__c>();
    for(PBSI__PBSI_Item_Group__c m:model_o) model_map.put(m.Id,m);

//  String[] bed_color_opts = new List<String>();
    String[] bed_color_opts_m = new List<String>();
    String[] firmness_opts = new List<String>();
    String[] mattress_struct_opts = new List<String>();
    String[] base_struct_opts = new List<String>();
//  Schema.DescribeFieldResult bed_color_fld = PBSI__PBSI_Item_Group__c.Colours_Available__c.getDescribe();
//  for(Schema.PicklistEntry ple:bed_color_fld.getPicklistValues()) bed_color_opts.add(ple.getValue());
    Schema.DescribeFieldResult bed_firmness_fld = PBSI__Quote_Line__c.Firmness__c.getDescribe();
    for(Schema.PicklistEntry ple:bed_firmness_fld.getPicklistValues()) firmness_opts.add(ple.getValue());
    Schema.DescribeFieldResult mattress_struct_fld = PBSI__Quote_Line__c.Bed_Custom_Mattress__c.getDescribe();
    for(Schema.PicklistEntry ple:mattress_struct_fld.getPicklistValues()) mattress_struct_opts.add(ple.getValue());
    Schema.DescribeFieldResult base_struct_fld = PBSI__Quote_Line__c.Bed_Custom_Base__c.getDescribe();
    for(Schema.PicklistEntry ple:base_struct_fld.getPicklistValues()) base_struct_opts.add(ple.getValue());

    PBSI__PBSI_Item__c vip_clip_item;
    PBSI__PBSI_Item__c nameplates;

    if(null!=bed_dtls.get('model_id') ) {
        String mdl = bed_dtls.get('model_id');
        PBSI__PBSI_Item_Group__c m_dtl = model_map.get( bed_dtls.get('model_id') );
        if(null!= m_dtl) { 
            Id vip_clip_id = m_dtl.VIP_Clips_for_this_Item_Group__c;
            Id nameplate_id = m_dtl.Nameplates_for_this_item_group__c;
            
            if( null!= vip_clip_id ) for(PBSI__PBSI_Item__c vc:[SELECT Id,PBSI__salesprice__c FROM PBSI__PBSI_Item__c WHERE Id=:vip_clip_id LIMIT 1]) vip_clip_item=vc;
            if( null!= nameplate_id ) for(PBSI__PBSI_Item__c n:[SELECT Id,PBSI__salesprice__c FROM PBSI__PBSI_Item__c WHERE Id=:nameplate_id LIMIT 1]) nameplates=n;
            
            leg_o = [SELECT Id, Name, PBSI__Quantity__c, PBSI__Item__c, PBSI__Item__r.Name, PBSI__Item__r.PBSI__description__c,PBSI__Item__r.PBSI__salesprice__c FROM PBSI__Configuration_Item__c WHERE PBSI__Configuration_Group__c=:m_dtl.Leg_Options_Models_Only__c ORDER BY PBSI__Item__r.PBSI__description__c];
            if( null!= m_dtl.Mattress_Topper_Options_Model_Only__c )
                topper_o = [SELECT Id, Name, PBSI__Quantity__c, PBSI__Item__c, PBSI__Item__r.Name, PBSI__Item__r.PBSI__description__c FROM PBSI__Configuration_Item__c WHERE PBSI__Configuration_Group__c=:m_dtl.Mattress_Topper_Options_Model_Only__c ORDER BY PBSI__Item__r.PBSI__description__c, PBSI__Item__r.Name];
    
            if(null!=bed_dtls.get('bed_size') && ''!=bed_dtls.get('bed_size') && null!=bed_dtls.get('topm_id') && ''!=bed_dtls.get('topm_id')) { 
                String bsz = bed_dtls.get('bed_size');
                String tm = bed_dtls.get('topm_id');
                bed_matches = [SELECT Id,Name,PBSI__description__c,Bed_Size__c,PBSI__Photo_URL__c,PBSI__salesprice__c FROM PBSI__PBSI_Item__c WHERE PBSI__Item_Group__r.PBSI__Item_Group_Code__c='GB' AND Model_LU__c=:mdl AND PBSI__Not_Available_For_Sale__c=false AND Bed_Size__c=:bsz AND Bed_Size__c!='x' AND Mattress_Topper_Choice__c=:tm];
                result.put('bed_matches',bed_matches);
            } else if(  null== m_dtl.Mattress_Topper_Options_Model_Only__c && null!=bed_dtls.get('bed_size') && ''!=bed_dtls.get('bed_size') ) { 
                String bsz = bed_dtls.get('bed_size');
                bed_matches = [SELECT Id,Name,PBSI__description__c,Bed_Size__c,PBSI__Photo_URL__c,PBSI__salesprice__c FROM PBSI__PBSI_Item__c WHERE PBSI__Item_Group__r.PBSI__Item_Group_Code__c='GB' AND Model_LU__c=:mdl AND PBSI__Not_Available_For_Sale__c=false AND Bed_Size__c=:bsz AND Bed_Size__c!='x'];
                result.put('bed_matches',bed_matches);
            }
            for(PBSI__PBSI_Item__c b:[SELECT Bed_Size__c FROM PBSI__PBSI_Item__c WHERE PBSI__Item_Group__r.PBSI__Item_Group_Code__c='GB' AND Model_LU__c=:mdl AND PBSI__Not_Available_For_Sale__c=false]) {
                if(null!=b.Bed_Size__c && 'x'!=b.Bed_Size__c) size_o.put(b.Bed_Size__c,1+ (null==size_o.get(b.Bed_Size__c) ? 0 : size_o.get(b.Bed_Size__c)) );
            }
            List<String> sz_o = new List<String>();
            sz_o.addAll( size_o.keySet() );
            sz_o.sort();
            result.put('size_opts',sz_o);

            set<string> clr_ex = new set<string>();
            if(null!= m_dtl.Color_Exclusions_For_This_Model__c) clr_ex.addAll(m_dtl.Color_Exclusions_For_This_Model__c.split(';'));
            Schema.DescribeFieldResult bed_color_fld_m = PBSI__PBSI_Item_Group__c.Color_Exclusions_For_This_Model__c.getDescribe();
            for(Schema.PicklistEntry ple:bed_color_fld_m.getPicklistValues()) {
                String pl_val = ple.getValue();
                if( !clr_ex.contains(pl_val) )
                    bed_color_opts_m.add(pl_val);
            }
        }
    }

    result.put('model_o',model_o);
    result.put('leg_o',leg_o);
    result.put('topper_o',topper_o);
//  result.put('bed_color_opts',bed_color_opts);
    result.put('bed_color_opts_m',bed_color_opts_m);
    result.put('firmness_opts',firmness_opts);
    result.put('mattress_struct_opts',mattress_struct_opts);
    result.put('base_struct_opts',base_struct_opts);
    result.put('v_c',vip_clip_item);
    result.put('nameplates',nameplates);
    result.put('success',1);
    return result;
}

static Map<Id,PBSI__PBSI_Item__c> match_past_beds(List<PBSI__Quote_Line__c> bed_qls) {
// TBD this will attempt to match existing Items at checkout time.
    set<Id> mdls = new set<Id>();
    set<String> szs = new set<String>();
    set<String> colrs = new set<String>();
    set<String> fmns = new set<String>();
    for(PBSI__Quote_Line__c ql:bed_qls) {
        if('GB'!=ql.PBSI__Item__r.PBSI__Item_Group__r.PBSI__Item_Group_Code__c) continue;
        if(null!= ql.PBSI__Item__r.Model_LU__c) mdls.add(ql.PBSI__Item__r.Model_LU__c);
        if(null!= ql.PBSI__Item__r.Bed_Size__c) szs.add(ql.PBSI__Item__r.Bed_Size__c);
        if(null!= ql.Fabric_Colour__c) colrs.add(ql.Fabric_Colour__c);
        if(null!= ql.Firmness__c) fmns.add(ql.Firmness__c);
    }
    Map<Id,PBSI__PBSI_Item__c> matches = new Map<Id,PBSI__PBSI_Item__c>();
    for(PBSI__PBSI_Item__c itm:[SELECT Id,Model_LU__c,Bed_Size__c,Color__c,Firmness_Options__c FROM PBSI__PBSI_Item__c 
        WHERE PBSI__Not_Available_For_Sale__c=false AND PBSI__Item_Group__r.PBSI__Item_Group_Code__c='BED' 
        AND Model_LU__c IN :mdls AND Bed_Size__c IN :szs AND Color__c IN :colrs AND Firmness_Options__c IN :fmns ]) {
        for(PBSI__Quote_Line__c ql:bed_qls) {
            if( itm.Model_LU__c == ql.PBSI__Item__r.Model_LU__c
                && itm.Bed_Size__c == ql.PBSI__Item__r.Bed_Size__c
                && itm.Color__c == ql.Fabric_Colour__c
                && itm.Firmness_Options__c == ql.Firmness__c ) {
                PBSI__PBSI_Item__c m_i = matches.get(ql.Id);
                if(null== m_i || m_i.CreatedDate < itm.CreatedDate) matches.put(ql.Id,itm);
            }
        }
    }
    return matches;
}

@RemoteAction
global static Map<String,Object> do_POS_quote2so(Id q_id) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();
    if(null==q_id) { doErr('Quote Line ID must be provided','K001',result); return result; }
    PBSI__Quote__c quot = [SELECT Id,PBSI__Account__c,PBSI__Status__c,Total_Sales_Tax_Avatax__c,Actual_Total_Sales_Tax__c,PBSI__Shipping_Cost__c,
        PBSI__Disable_Trade_Agreements__c,PBSI__Trade_Agreement__c  
        FROM PBSI__Quote__c WHERE Id=:q_id LIMIT 1];
    if(null== quot) {doErr('Couldnt get quote ','D002',result); return result;}

    Id rt,so_id;
    try { 
//      Map<String,Schema.RecordTypeInfo> rti = Schema.SObjectType.PBSI__PBSI_Sales_Order__c.getRecordTypeInfosByName();
//      Map<String,String> rts = new Map<String,String>();
//      for(String rtk:rti.keySet()) rts.put(rtk,rti.get(rtk).getName());
        rt = Schema.SObjectType.PBSI__PBSI_Sales_Order__c.getRecordTypeInfosByName().get('New Sales Order').getRecordTypeId();
        result.put('so_rt',rt);
    } catch(Exception e) { 
        doErr('Couldnt get Sales Order record type','D002',result); return result;
    }
    PBSI__PBSI_Sales_Order__c nw_so;
    try { 
        nw_so = new PBSI__PBSI_Sales_Order__c(RecordTypeId=rt);
        nw_so.PBSI__From_Quote__c = q_id;
        nw_so.PBSI__Customer__c = quot.PBSI__Account__c;
        nw_so.Sales_Tax_Total_From_Quote__c = quot.Actual_Total_Sales_Tax__c;
        nw_so.PBSI__Shipping_Cost__c = quot.PBSI__Shipping_Cost__c;
        nw_so.PBSI__Disable_Sales_Trade_Agreement__c = quot.PBSI__Disable_Trade_Agreements__c;
        nw_so.PBSI__Trade_Agreement__c = quot.PBSI__Trade_Agreement__c;

        insert nw_so;
        result.put('so_id',nw_so.Id);
        result.put('nw_so',nw_so);
    } catch(Exception e) { 
        doErr('Couldnt create Sales Order','D001',result); return result;
    }

    set<String> bed_IGCs = new set<String>{'GB'};
    PBSI__Quote_Line__c[] q_lines = [SELECT Id,Name,CreatedDate,PBSI__Description__c,PBSI__Quantity__c,PBSI__Quote__c,
        PBSI__Item__r.PBSI__Item_Group__r.PBSI__Item_Group_Code__c,PBSI__Item__r.Range_LU__r.Name,PBSI__Item__r.Model_LU__r.Name,
        PBSI__Item__r.Bed_Size__c,PBSI__Item__r.Color__c,PBSI__Item__r.Firmness_Options__c,PBSI__Item__r.Name,
        PBSI__Item__r.PBSI__description__c,
        POS_Discounted_Price__c,POS_Line_Subtotal__c,SalesTax_Rate_Avatax__c,
        Fabric_Colour__c,Firmness__c,VIP_Clips__c,
        Bed_Custom_Size__c, Bed_Custom_Firmness__c, Bed_Custom_Mattress__c,Bed_Custom_Base__c, PBSI__Parent_Line__c,
        Bed_Topper__c,Bed_Topper__r.Name,Bed_Legs__c,Bed_Legs__r.PBSI__description__c 
        FROM PBSI__Quote_Line__c WHERE PBSI__Quote__c =:q_id];

    Map<Id,PBSI__PBSI_Item__c> existing_items = match_past_beds(q_lines);
    PBSI__PBSI_Sales_Order_Line__c[] nw_sols = new List<PBSI__PBSI_Sales_Order_Line__c>();
    try { 
        for(PBSI__Quote_Line__c ql:q_lines) {
            PBSI__PBSI_Sales_Order_Line__c nw_sol = new PBSI__PBSI_Sales_Order_Line__c(PBSI__Sales_Order__c=nw_so.Id);
            nw_sol.PBSI__Quantity_Needed__c = ql.PBSI__Quantity__c;
            if(null!=ql.PBSI__Description__c && ''!= ql.PBSI__Description__c) nw_sol.PBSI__ItemDescription__c = ql.PBSI__Description__c;
            nw_sol.Fabric_Colour__c = ql.Fabric_Colour__c;
            nw_sol.Firmness__c = ql.Firmness__c;
            nw_sol.PBSI__From_Quote__c = true;
            nw_sol.VIP_Clips__c = ql.VIP_Clips__c;
            nw_sol.Bed_Topper__c = ql.Bed_Topper__c;
            nw_sol.Bed_Legs__c = ql.Bed_Legs__c;
//          nw_sol.PBSI__Price__c = ql.POS_Discounted_Price__c;
            nw_sol.Sale_Price_From_Quote__c = ql.POS_Discounted_Price__c;
            nw_sol.PBSI__Tax__c = ql.SalesTax_Rate_Avatax__c;
            nw_sol.Bed_Custom_Size__c = ql.Bed_Custom_Size__c;
            nw_sol.Bed_Custom_Firmness__c = ql.Bed_Custom_Firmness__c;
            nw_sol.Bed_Custom_Mattress__c = ql.Bed_Custom_Mattress__c;
            nw_sol.Bed_Custom_Base__c = ql.Bed_Custom_Base__c;
            
            PBSI__PBSI_Item__c x_i = existing_items.get(ql.Id);
            if(null== x_i) nw_sol.PBSI__Item__c = ql.PBSI__Item__c;
            else nw_sol.PBSI__Item__c = x_i.Id;

            nw_sols.add(nw_sol);
        }
        insert nw_sols;
    } catch(Exception e) {
        doErr('Couldnt create Sales Order lines','D003',result); return result;
    }
    try {
        map<Id,Id> qol2sol = new map<Id,Id>();
        PBSI__PBSI_Sales_Order_Line__c[] sol_wp = new list<PBSI__PBSI_Sales_Order_Line__c>();
        for(Integer i=0; i<nw_sols.size() ; i++) {
            PBSI__PBSI_Sales_Order_Line__c sol = nw_sols[i];
            PBSI__Quote_Line__c qol = q_lines[i];
            if(sol.Id != null && qol.Id != null) qol2sol.put(qol.Id,sol.Id);
        }
        for(Integer i=0; i<nw_sols.size() ; i++) {
            PBSI__PBSI_Sales_Order_Line__c sol = nw_sols[i];
            PBSI__Quote_Line__c qol = q_lines[i];
            if(sol.Id != null && qol.PBSI__Parent_Line__c != null) {
                sol.PBSI__Parent_Line__c = qol2sol.get(qol.PBSI__Parent_Line__c);
                sol_wp.add(sol);
            }
        }
        update sol_wp;
    } catch(Exception e) {
        doErr('Couldnt set parent Sales Order lines','D005',result); return result;
    }

    try { 
        quot.PBSI__Status__c = 'Converted';
        update quot;
    } catch(Exception e) {
        doErr('Couldnt mark Quote as converted','D004',result); return result;
    }

    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> list_accy_options(Map<String,String> accy_dtls,Integer pg_num) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();
    List<PBSI__PBSI_Item__c> accy_matches = new List<PBSI__PBSI_Item__c>();

    if(null==accy_dtls) { doErr('Accessory details must be provided','K001',result); return result; }

//    Map<String,Integer> types_o = new Map<String,Integer>();
    Map<String,Integer> size_o = new Map<String,Integer>();

    List<PBSI__PBSI_Item_Group__c> types_l = [SELECT Id,Name,PBSI__Item_Group_Code__c FROM PBSI__PBSI_Item_Group__c WHERE PBSI__Parent_Group__r.PBSI__Item_Group_Code__c='ACC' ORDER BY Name];

    String[] bmq_where_list = new List<String>{' PBSI__Not_Available_For_Sale__c=false '};
    if(null!=accy_dtls.get('accy_inum') && ''!=accy_dtls.get('accy_inum') ) {
        bmq_where_list.add('Name=\''+ String.escapeSingleQuotes(accy_dtls.get('accy_inum')) +'\'');

        String bmq_where = String.join(bmq_where_list, ' AND ');
//System.debug('***Qry:');
//System.debug('SELECT Id,Name,PBSI__description__c,Bed_Size__c,PBSI__Photo_URL__c,PBSI__salesprice__c FROM PBSI__PBSI_Item__c WHERE PBSI__Not_Available_For_Sale__c=false AND '+bmq_where+' ORDER BY CreatedDate LIMIT 1');
        accy_matches = Database.query('SELECT Id,Name,PBSI__description__c,Bed_Size__c,PBSI__Photo_URL__c,PBSI__salesprice__c FROM PBSI__PBSI_Item__c WHERE '+bmq_where+' ORDER BY CreatedDate LIMIT 1');
        for(PBSI__PBSI_Item__c b:accy_matches) {
            if(null!=b.Bed_Size__c && 'x'!=b.Bed_Size__c) size_o.put(b.Bed_Size__c,1+ (null==size_o.get(b.Bed_Size__c) ? 0 : size_o.get(b.Bed_Size__c)) );
        }
    } else if( (null!=accy_dtls.get('accy_type') && ''!=accy_dtls.get('accy_type')) || (null!=accy_dtls.get('accy_keys') && ''!=accy_dtls.get('accy_keys')) ) {
        if(null!=accy_dtls.get('accy_type') && ''!=accy_dtls.get('accy_type')) { bmq_where_list.add('PBSI__Item_Group__c=\''+accy_dtls.get('accy_type')+'\''); }
        if(null!=accy_dtls.get('accy_size') && ''!=accy_dtls.get('accy_size')) { bmq_where_list.add('Bed_Size__c=\''+accy_dtls.get('accy_size')+'\''); }
        if(null!=accy_dtls.get('accy_keys') && ''!=accy_dtls.get('accy_keys') && accy_dtls.get('accy_keys').isAlphanumericSpace()) { 
            String[] aks = accy_dtls.get('accy_keys').split(' ');
            Integer k_l = 3;
            for(String ak:aks) {
                String ak_cl = ak.deleteWhitespace();
                if(''!=ak_cl) {
                    bmq_where_list.add('PBSI__description__c LIKE \'%'+ak_cl+'%\'');
                    k_l--;
                    if(k_l<=0) break;
                }
            }
        }

        Integer pg_len = 20;
        Integer pg_offs = pg_len* pg_num;
        String bmq_where = String.join(bmq_where_list, ' AND ');
        accy_matches = Database.query('SELECT Id,Name,PBSI__description__c,Bed_Size__c,PBSI__Photo_URL__c,PBSI__salesprice__c FROM PBSI__PBSI_Item__c WHERE '+bmq_where+' ORDER BY PBSI__description__c LIMIT '+(1+pg_len).format()+' OFFSET '+pg_offs.format());
        for(PBSI__PBSI_Item__c b:accy_matches) {
            if(null!=b.Bed_Size__c && 'x'!=b.Bed_Size__c) size_o.put(b.Bed_Size__c,1+ (null==size_o.get(b.Bed_Size__c) ? 0 : size_o.get(b.Bed_Size__c)) );
        }
    }
    Integer n_matches = accy_matches.size();
    result.put('n_matches',n_matches);
//    if(n_matches<20) result.put('accy_matches',accy_matches);
    result.put('accy_matches',accy_matches);
    result.put('types_l',types_l);
    result.put('size_o',size_o);
//    result.put('types_o',types_o);
    result.put('success',1);
    return result;
}

/*
@RemoteAction
global static Map<String,Object> quote_line_spec(Id ql_id) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    PBSI__Quote_Line__c[] q_lines = [SELECT Id,Name,CreatedDate,PBSI__Description__c,PBSI__Quantity__c,PBSI__Quote__c,
        PBSI__Parent_Line__c,PBSI__Item__c,
        PBSI__Item__r.PBSI__Item_Group__r.PBSI__Item_Group_Code__c,PBSI__Item__r.Range_LU__r.Name,
        PBSI__Item__r.Model_LU__r.Name, PBSI__Item__r.Model_LU__c,
        PBSI__Item__r.Model_LU__r.Leg_Options_Models_Only__c, PBSI__Item__r.Model_LU__r.Mattress_Topper_Options_Model_Only__c,
        PBSI__Item__r.Bed_Size__c,PBSI__Item__r.Color__c,PBSI__Item__r.Firmness_Options__c,PBSI__Item__r.Name,
        PBSI__Item__r.PBSI__description__c,
        POS_Discounted_Price__c,POS_Line_Subtotal__c,
        Fabric_Colour__c,Firmness__c,VIP_Clips__c,
        Bed_Topper__c,Bed_Topper__r.PBSI__description__c,Bed_Legs__c,Bed_Legs__r.PBSI__description__c,
        Bed_Custom_Size__c, Bed_Custom_Firmness__c, Bed_Custom_Mattress__c, Bed_Custom_Base__c
        FROM PBSI__Quote_Line__c WHERE Id =:ql_id];
    if(q_lines.size() !=1) { doErr('Couldnt open Quote Line','K001',result); return result; }
    PBSI__Quote_Line__c q_l = q_lines[0];
    result.put('q_l',q_l);
    set<String> bed_IGCs = new set<String>{'GB'};
    
    if(null!=q_l.PBSI__Item__r && null!=q_l.PBSI__Item__r.PBSI__Item_Group__r && bed_IGCs.contains(q_l.PBSI__Item__r.PBSI__Item_Group__r.PBSI__Item_Group_Code__c)) {
        result.put('spec_type','bed_spec');
        result.put('bed_model',q_l.PBSI__Item__r.Model_LU__r.Name);
        result.put('model_id',q_l.PBSI__Item__r.Model_LU__c);
        result.put('model_dtl',q_l.PBSI__Item__r.Model_LU__r);
        result.put('bed_color',q_l.Fabric_Colour__c);
        result.put('bed_firmness',q_l.Firmness__c);
        result.put('bed_size',q_l.PBSI__Item__r.Bed_Size__c);
    }

    result.put('success',1);
    return result;
}
*/      

@RemoteAction
global static Map<String,Object> upd_q_shipp_amt(String q_id,Decimal qty) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();
    if(null==q_id) { doErr('Quote Line ID must be provided','K001',result); return result; }
    PBSI__Quote__c quot = [SELECT Id,PBSI__Shipping_Cost__c FROM PBSI__Quote__c WHERE Id=:q_id LIMIT 1];
    if(null== quot) {doErr('Couldnt get quote ','D002',result); return result;}

    quot.PBSI__Shipping_Cost__c = qty;
    upsert quot;

    result.put('quot',quot);
    result.put('success',1);
    return result;
}
@RemoteAction
global static Map<String,Object> upd_ord_shipp_amt(String o_id,Decimal qty) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==o_id) { doErr('Quote ID must be provided','K001',result); return result; }
    PBSI__PBSI_Sales_Order__c ord = [SELECT Id,PBSI__Shipping_Cost__c FROM PBSI__PBSI_Sales_Order__c WHERE Id=:o_id LIMIT 1];
    if(null== ord)  {doErr('Couldnt get order ','D002',result); return result;}

    ord.PBSI__Shipping_Cost__c = qty;
    upsert ord;

    result.put('ord',ord);
    result.put('success',1);
    return result;
}

@RemoteAction
global static Map<String,Object> get_disc_ql(String ql_id) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==ql_id) { doErr('Quote Line ID must be provided','K001',result); return result; }
    PBSI__Quote_Line__c q_line = [SELECT Id,Name,CreatedDate,PBSI__Quantity__c,PBSI__Quote__c,
        POS_Discounted_Price__c,POS_Line_Subtotal__c,SalesTax_Rate_Avatax__c,
        PBSI__Sale_Price__c, PBSI__Parent_Line__c, PBSI__Discount__c,Bed_Legs__c
        FROM PBSI__Quote_Line__c WHERE Id =:ql_id];
    if(null== q_line)   {doErr('Couldnt get Quote Line ','D002',result); return result;}

    PBSI__Quote_Line__c q_leg;
    try { 
        q_leg = [SELECT Id,Name,CreatedDate,PBSI__Quantity__c,PBSI__Quote__c,
            POS_Discounted_Price__c,POS_Line_Subtotal__c,SalesTax_Rate_Avatax__c,
            PBSI__Sale_Price__c, PBSI__Parent_Line__c, PBSI__Discount__c,PBSI__Item__c
            FROM PBSI__Quote_Line__c WHERE PBSI__Parent_Line__c =:ql_id AND PBSI__Item__c=:q_line.Bed_Legs__c];
    } catch(Exception e) {}

    result.put('q_line',q_line);
    result.put('q_leg',q_leg);
    result.put('success',1);
    return result;
}
@RemoteAction
global static Map<String,Object> set_disc_ql(String ql_id,String fld,Decimal pct_val) {
    Map<String,Object> result = new Map<String,Object>();
    String[] errors = new List<String>();

    if(null==ql_id) { doErr('Quote Line ID must be provided','K001',result); return result; }
    PBSI__Quote_Line__c q_line = [SELECT Id,Name,CreatedDate,PBSI__Quantity__c,PBSI__Quote__c,
        POS_Discounted_Price__c,POS_Line_Subtotal__c,SalesTax_Rate_Avatax__c,
        PBSI__Sale_Price__c, PBSI__Parent_Line__c, PBSI__Discount__c,Bed_Legs__c
        FROM PBSI__Quote_Line__c WHERE Id =:ql_id];
    if(null== q_line)   {doErr('Couldnt get Quote Line ','D002',result); return result;}

    PBSI__Quote_Line__c q_leg;
    if(fld=='legs') {
        try { 
            q_leg = [SELECT Id,Name,CreatedDate,PBSI__Quantity__c,PBSI__Quote__c,
                POS_Discounted_Price__c,POS_Line_Subtotal__c,SalesTax_Rate_Avatax__c,
                PBSI__Sale_Price__c, PBSI__Parent_Line__c, PBSI__Discount__c,PBSI__Item__c
                FROM PBSI__Quote_Line__c WHERE PBSI__Parent_Line__c =:ql_id AND PBSI__Item__c=:q_line.Bed_Legs__c];
        } catch(Exception e) {}
        if(null!= q_leg) {
            q_leg.PBSI__Discount__c = pct_val;
            update q_leg;
        }
    } else {
        q_line.PBSI__Discount__c = pct_val;
        update q_line;      
    }

    result.put('success',1);
    return result;
}

}