// Written by David Habib, copyright (c) 2010, 2011 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is free software; you can redistribute it and/or modify it under the terms of the 
// GNU General Public License version 3 as published by the Free Software Foundation. http://www.gnu.org/licenses/gpl.html

global virtual with sharing class VOL_CTRL_VolunteersBulkEnterHours {

    global integer cEmptyVolunteerHourRecords {
        get {
            return 5;
        }
    }
    
    private VOL_SharedCode volSharedCode;
    private list<string> listStrFields;
    
    // constructor
    global VOL_CTRL_VolunteersBulkEnterHours() {
        volSharedCode = new VOL_SharedCode();
        listSOCampaigns = volSharedCode.listSOCampaignsWithJobs;
        
        // handle optional parameters (must use string, not ID, to handle null)
        string id = ApexPages.currentPage().getParameters().get('campaignId');
        if (id != null && id != '') campaignId = id;
        
        id = ApexPages.currentPage().getParameters().get('volunteerJobId');
        if (id != null && id != '') volunteerJobId = id;

        id = ApexPages.currentPage().getParameters().get('volunteerShiftId');
        if (id != null && id != '') volunteerShiftId = id;
        
        
		// initialize the list of all fields on Volunteer Hours.
		Map<String, Schema.SObjectField> mapS = Schema.SObjectType.Volunteer_Hours__c.fields.getMap();
		listStrFields = new list<string>();
		listStrFields.addAll(mapS.keySet());  
		
		/* here is code that would use metadata api for fieldsets.
		unfortunately, the user then won't get an error if they include a field from a related object,
		but we won't update it either.  Thus I think it is better to just get the fields on the Hours
		object so if they add a related field to contacts (for example), they will get a runtime error
		trying to display the page.
		
        for (Schema.FieldSetMember f : SObjectType.Volunteer_Hours__c.FieldSets.GW_Volunteers__MassEditVolunteerHours.getFields()) {
            listStrFields.add(f.getFieldPath());
        }
        // add fields we hardcode on the page
        listStrFields.add('Volunteer_Shift__c');
        listStrFields.add('Contact__c');
		*/
		      		          
    }   

    
    // holds the currently selected Campaign in the Campaign dropdown
    global ID campaignId { get; set; }

    // the list of Campaigns to put in the Campaign dropdown
    global list<SelectOption> listSOCampaigns { get; set; }
    
    // the user has changed the Campaign dropdown
    global virtual PageReference ChangeCampaign() {
        // clear out all state that is specific to the campaign
        listSOVolunteerJobs = null;
        volunteerJobId = null;
        ChangeVolunteerJob();
        return null;
    }

    // holds the currently select Job in the Job dropdown
    global ID volunteerJobId { get; set; }
    
    // the list of Volunteer Jobs to put in the dropdown
    global list<SelectOption> listSOVolunteerJobs {
        get {
            if (listSOVolunteerJobs == null && campaignId != null) {
                listSOVolunteerJobs = volSharedCode.listSOVolunteerJobsOfCampaignId(campaignId);
            }
            return listSOVolunteerJobs;
        }
        
        set;
    }
    
	// dates to filter the list of shifts and hours we are displaying
    global date startDate { get; set; }
    global date endDate { get; set; }
    
    global Volunteer_Hours__c vhDateFilter {
    	get {
    		if (vhDateFilter == null) {
    			vhDateFilter = new Volunteer_Hours__c();
				// initial date range
				vhDateFilter.Start_Date__c = system.today().addMonths(-1).toStartOfMonth();
				vhDateFilter.End_Date__c = system.today().addMonths(2).toStartOfMonth().addDays(-1);      			
    		}
    		return vhDateFilter;
    	}
    	set;
    }

    // the user has changed the Volunteer Job dropdown
    global virtual PageReference ChangeVolunteerJob() {
        // clear out all state that is specific to the Job
        listSOVolunteerShifts = null;
        volunteerShiftId = null;
        listVolunteerHours = null;
        strSaveResults = null;
        return null;
    }

    // holds the currently select Job Shift in the Job Shift dropdown
    global ID volunteerShiftId { get; set; }
    
    // the list of Volunteer Shifts to put in the dropdown
    global list<SelectOption> listSOVolunteerShifts {
        get {
            if (listSOVolunteerShifts == null && volunteerJobId != null) {
                listSOVolunteerShifts = volSharedCode.listSOVolunteerShiftsOfVolunteerJobId(volunteerJobId, 
                	vhDateFilter.Start_Date__c, vhDateFilter.End_Date__c, true, false); 
            }
            return listSOVolunteerShifts;
        }
        
        set;
    }

    // the user has changed the Volunteer Shift dropdown
    global virtual PageReference ChangeVolunteerShift() {
        // clear out all state that is specific to the Shift
        listVolunteerHours = null;
        return null;
    }

    // status string for reporting the results of saving.
    global String strSaveResults { get; set; }
      
    // The list of Volunteer Hours.
    global list<Volunteer_Hours__c> listVolunteerHours {
        get {
            if (listVolunteerHours == null) {
                FillListVolunteerHours();
            }
            return listVolunteerHours;
        }
        
        set;
    }
    
    // helper function that the client can override, to query for the appropriate fields in Volunteer_Hours.
    global virtual void FillListVolunteerHours() {
        // if they haven't yet picked a job, there are no hours to show or add.
        if (volunteerJobId == null) return;           
		
		// find the existing jobs
		// we need to use dynamic soql to pick up all custom fields we don't know about
        string strSoql = 'select ';
        string strComma = '';
        for (string strF : listStrFields) {
        	strSoql += strComma + strF;
        	strComma = ', ';
        }
        strSoql += ' from Volunteer_Hours__c where Volunteer_Job__c = :volunteerJobId ';
        if (volunteerShiftId != null) {
        	strSoql += ' and Volunteer_Shift__c = :volunteerShiftId ';
        }
        if (vhDateFilter.Start_Date__c != null) {
        	Date dtStart = vhDateFilter.Start_Date__c;
        	strSoql += ' and Start_Date__c >= :dtStart ';
        }
        if (vhDateFilter.End_Date__c != null) {
        	Date dtEnd = vhDateFilter.End_Date__c;
        	strSoql += ' and Start_Date__c <= :dtEnd ';
        }
        strSoql += ' order by Full_Name__c, Start_Date__c ';
        
        listVolunteerHours = Database.Query(strSoql); 
                
        AddMoreEmptyRowsToVolunteerHours();
    }
    
    global Boolean fHasListVolunteerHours {
        get {
            return listVolunteerHours != null && listVolunteerHours.size() > 0;
        }
    }     
 
    global virtual void AddMoreEmptyRowsToVolunteerHours() {
        if (listVolunteerHours == null) return;

        // cache info from Shift if we have it
        double hoursWorked;
        date dateStart;
        if (volunteerShiftId != null) {
                Volunteer_Shift__c vs = [select Id, Duration__c, Start_Date_Time__c from Volunteer_Shift__c where Id = :volunteerShiftId];
                hoursWorked = vs.Duration__c;
                dateStart = vs.Start_Date_Time__c.date();
        }
        
        for (integer i = 0; i < cEmptyVolunteerHourRecords; i++) { 
            Volunteer_Hours__c vh = new Volunteer_Hours__c();
            vh.Status__c = 'Completed';
            vh.Number_of_Volunteers__c = 1;
            vh.Volunteer_Job__c = volunteerJobId;
            vh.Volunteer_Shift__c = volunteerShiftId;
            if (volunteerShiftId != null) {
                vh.Hours_Worked__c = hoursWorked;
                vh.Start_Date__c = dateStart;
            }
            listVolunteerHours.add(vh);
        }       
    }
    
    // used to track the Id's of all VolunteerHour records that get modified.
    global Set<ID> setVolunteerHoursIdDirty {
        get {
            if (setVolunteerHoursIdDirty == null) {
                setVolunteerHoursIdDirty = new Set<ID>();
            }
            return setVolunteerHoursIdDirty;
        }
        set;
    }
    
    // to allow vf page to see how many VolunteerHour records are dirty
    global Integer numberOfRecordsDirty {
        get { 
            if (setVolunteerHoursIdDirty == null)
                return 0;
            else
                return setVolunteerHoursIdDirty.size();
        }
    }
    
    // this gets called whenever a field in the VolunteerHours datatable is modified.
    // use this to remember which existing VolunteerHours records have been modified.
    global virtual PageReference VolunteerHoursRecordModified() {
        String strId = ApexPages.currentPage().getParameters().get('volunteerHoursIdDirtied');
        if (strId != null && strId != '') setVolunteerHoursIdDirty.add(strId);
        return null;
    }

    //save the Volunteer Hours created or modified
    global virtual PageReference SaveVolunteerHours() {
        
        if (listVolunteerHours == null) return null;
        
        strSaveResults = null;
        
        try {
            // create two lists: one to update and one to insert.
            list<Volunteer_Hours__c> listVolunteerHoursCreate = new list<Volunteer_Hours__c>();
            list<Volunteer_Hours__c> listVolunteerHoursUpdate = new list<Volunteer_Hours__c>();

            for (Volunteer_Hours__c vh : listVolunteerHours) {
                if (vh.Id != null) {
                    if (setVolunteerHoursIdDirty.contains(vh.Id)) listVolunteerHoursUpdate.add(vh);
                } else if (vh.Contact__c != null) {
                    listVolunteerHoursCreate.add(vh);
                }
            }
            update listVolunteerHoursUpdate;
            insert listVolunteerHoursCreate;
            strSaveResults = String.valueOf(listVolunteerHoursCreate.size() + listVolunteerHoursUpdate.size()) + ' ' + Label.labelMassEditSaveSuccess;
            // successful save, so clear out dirty list
            setVolunteerHoursIdDirty = null;
            return null;            
        } catch (Exception e) {
            strSaveResults = Label.labelMassEditErrorOnSave;
            ApexPages.addMessages(e);            
            return null;
        }
    }

    //save the Volunteer Hours created or modified, and then close the page.
    global virtual PageReference SaveAndCloseVolunteerHours() {
        SaveVolunteerHours();
        return Cancel();    
    }
    
    // user wants to close this page
    global virtual PageReference Cancel() {
        string strURL = ApexPages.currentPage().getParameters().get('retURL');
        if (strURL == null || strURL == '') strURL = '\\';
        PageReference p = new PageReference(strURL);
        p.setRedirect(true);
        return p;
    }
    
    // user wants to add more empty rows to the Volunteer Hours table
    global PageReference AddMoreEmptyRows() {
        AddMoreEmptyRowsToVolunteerHours();
        return null;
    }
    
    
    //==================== TEST METHOD(s) ======================================
    global static testmethod void CodeCoverageTests() {
    
        // set up intial test data
        Account acc = new Account(name='Individual Test Account');
        insert acc;
        Contact con = new Contact(Lastname='Testy', AccountId=acc.Id);
        insert con;
        Campaign cmp = new Campaign(recordtypeid=VOL_SharedCode.recordtypeIdVolunteersCampaign, 
        	name='Test Campaign', IsActive=true);
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name='Job1', campaign__c=cmp.Id);
        insert job;
        Volunteer_Shift__c shift = new Volunteer_Shift__c(Volunteer_Job__c=job.Id, Duration__c=1, Start_Date_Time__c=System.now());
        insert shift;
        list<Volunteer_Hours__c> listHours = new list<Volunteer_Hours__c>();   
        integer cHours = 5;     
        for (integer i = 0; i < cHours; i++) {
            Volunteer_Hours__c hours = new Volunteer_Hours__c(
                Volunteer_Job__c=job.id, 
                Volunteer_Shift__c=shift.Id,
                Contact__c=con.Id,
                Number_of_Volunteers__c=3,
                Start_Date__c=System.today(), 
                Status__c='Confirmed'
                );
            listHours.add(hours);
        }                       
        insert listHours;
        
        //point to our VF page
        PageReference p = new PageReference('Page.VolunteersBulkEnterHours');
        p.getParameters().put('campaignId', cmp.id);
        p.getParameters().put('volunteerJobId', job.id);
        p.getParameters().put('volunteerShiftId', shift.id);
        Test.setCurrentPageReference(p);
        
        //instantiate the controller for this opp
        VOL_CTRL_VolunteersBulkEnterHours ctrl = new VOL_CTRL_VolunteersBulkEnterHours();
        System.AssertEquals(cmp.Id, ctrl.campaignId);
        System.AssertEquals(job.Id, ctrl.volunteerJobId);
        System.AssertEquals(shift.Id, ctrl.volunteerShiftId);
        System.Assert(ctrl.listSOCampaigns.size() > 1);
        System.AssertEquals(2, ctrl.listSOVolunteerJobs.size());
        System.AssertEquals(2, ctrl.listSOVolunteerShifts.size());
        System.AssertEquals(cHours + ctrl.cEmptyVolunteerHourRecords, ctrl.listVolunteerHours.size());
        
        ctrl.AddMoreEmptyRows();
        System.AssertEquals(cHours + (2 * ctrl.cEmptyVolunteerHourRecords), ctrl.listVolunteerHours.size());
        System.AssertEquals(true, ctrl.fHasListVolunteerHours);
        System.Assert(ctrl.Cancel() != null);
        System.AssertEquals(0, ctrl.numberOfRecordsDirty);
        System.AssertEquals(null, ctrl.strSaveResults); 

        ctrl.campaignId = null;
        ctrl.ChangeCampaign();
        System.AssertEquals(null, ctrl.volunteerJobId);
        System.AssertEquals(null, ctrl.volunteerShiftId);
        System.AssertEquals(null, ctrl.listVolunteerHours);
        
        ctrl.campaignId = cmp.Id;
        ctrl.ChangeCampaign();
        ctrl.volunteerJobId = job.Id;
        ctrl.ChangeVolunteerJob();
        System.AssertEquals(cHours + ctrl.cEmptyVolunteerHourRecords, ctrl.listVolunteerHours.size());
        ctrl.volunteerShiftId = shift.Id;
        ctrl.ChangeVolunteerShift();
        System.AssertEquals(cHours + ctrl.cEmptyVolunteerHourRecords, ctrl.listVolunteerHours.size());
        System.AssertEquals(0, ctrl.numberOfRecordsDirty);
        
        ctrl.listVolunteerHours.get(0).Hours_Worked__c = 2;
        p.getParameters().put('volunteerHoursIdDirtied', ctrl.listVolunteerHours.get(0).id);
        ctrl.VolunteerHoursRecordModified();
        System.AssertEquals(1, ctrl.setVolunteerHoursIdDirty.size());
        
        Volunteer_Hours__c vh = ctrl.listVolunteerHours.get(5);
        vh.Contact__c = con.id;
        vh.Volunteer_Job__c = job.id;
        vh.Volunteer_Shift__c = shift.id;
        vh.Status__c = 'Completed';
        vh.Start_Date__c = system.today();
        vh.Hours_Worked__c = null; // to test failure
        p.getParameters().put('volunteerHoursIdDirtied', null);
        ctrl.VolunteerHoursRecordModified();
        System.AssertEquals(1, ctrl.setVolunteerHoursIdDirty.size());
        System.AssertEquals(1, ctrl.numberOfRecordsDirty);

        // test the save!
        ctrl.SaveVolunteerHours();
        system.debug(ctrl.strSaveResults);
        System.Assert(ctrl.strSaveResults.startsWith('Error'));
        vh.Hours_Worked__c = 2.5;
        ctrl.SaveAndCloseVolunteerHours();      
        System.AssertEquals(0, ctrl.numberOfRecordsDirty);
        
    }
}