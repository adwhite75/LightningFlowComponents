/**
* @File Name			: SendBetterEmail.cls
 * @Description			: Uses Spring/Summer '20 EmailTemplate Object + ContentVersion with multi-lingual
 * @Credits				: Alex Edelstein, Jeremiah Dohn, etal
 * @Group				: unofficialSF
 * @Last Modified By	: Jack D. Pond
 * @Last Modified On	: 08-11-2020
 * @License				: LICENSE found in https://github.com/alexed1/LightningFlowComponents
 * @Modification Log	: 
 * 
 * Ver		Date		Author					Modification
 * 0.01					Alex Edelstein			Original Author
 * 1.32		2/5/2020	Jack Pond				Modified for multi-lingual and to throw InvocableActionException on exceptions
 * 1.32		2/11/2020	Alex Edelstein			Bulkified and Changed recordId to String
 * 1.33		3/22/2020	Jack Pond				Added consistency checks, modified Labels and alphabetized params
 * 1.33.1	4/11/2020	Jack Pond				Issues 308,316
 * 1.33.2	5/29/2020	Jack Pond				Version 1.33.2 upgrade - Issues #320,#351,#354, #355, #392
 * 1.33.2	6/02/2020	Jack Pond				Finalized MassEmail and added Tests and Issue #378
 * 2.00.00	6/02/2020	Jack Pond				SendBetterEmail - Optimize Bulkification #445
 * 
 * Done:
 * #320 sendBetterEmail - Activity History Redesign?
 * #351 sendBetterEmail - Address bulkification consistent with Apex Gov Limits
 * #354 sendBetterEmail - Limit Class test to 2 OrgWideEmailAddresses
 * #355 sendBetterEmail - Separate Email Activity from Email Task Activity
 * #378 sendBetterEmail - Allow selection of email template by name as well as by TemplateId
 * #392 sendBetterEmail - Return the Activity TaskId added
 * #342 sendBetterEmail CPE For Summer '20 Release
 * #445 SendBetterEmail - Optimize Bulkification
**/

public without sharing class SendBetterEmail {

//	@invocableMethod(label='Send Better Email')
	@invocableMethod(label='Send Better Email' configurationEditor='c:sendBetterEmailCPE')
	public static List<Response> SendEmail(List<Request> requests) {

		List<Response> responseList = new List<Response>();
		List<Messaging.SingleEmailMessage> mailList = new List<Messaging.SingleEmailMessage>();
		List<Messaging.MassEmailMessage> mailMMList = new List<Messaging.MassEmailMessage>();
		for (Request curRequest : requests) {
			String HTMLbody = curRequest.HTMLbody;
			String orgWideEmailAddressId = curRequest.orgWideEmailAddressId;
			String plainTextBody = curRequest.plainTextBody;
			String recordId = curRequest.recordId;
			String replyEmailAddress = curRequest.replyEmailAddress;
			String senderDisplayName = curRequest.senderDisplayName;
			String subject = curRequest.subject;
			String templateID = curRequest.templateID;
			String templateName = curRequest.templateName;
			String templateLanguage = curRequest.templateLanguage;
			String templateTargetObjectId = curRequest.templateTargetObjectId;
			String emailMessageType = curRequest.emailMessageType == null?'singleEmail':curRequest.emailMessageType;
			Boolean useSalesforceSignature = curRequest.useSalesforceSignature == null?true:curRequest.useSalesforceSignature;
			Boolean bcc = curRequest.bcc == null?false:curRequest.bcc; // default to false
			if (subject != null && (subject.length() == 0) ) subject = null;
			Response thisResponse = new Response();
			
			curRequest.setSaveAsActivity = curRequest.saveAsActivity == null?true:curRequest.saveAsActivity;
			if (recordId==null)curRequest.setSaveAsActivity = curRequest.saveAsActivity == null?false:curRequest.setSaveAsActivity;
			// saveAsTask will default to whatever saveAsActivity is, but if recordId is null, will set it to false
			curRequest.setSaveAsTask = curRequest.saveAsTask == null?curRequest.setSaveAsActivity:curRequest.saveAsTask;
			if (recordId==null)curRequest.setSaveAsTask = curRequest.setSaveAsTask == null?false:curRequest.setSaveAsTask;
			//from https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_forcecom_email_outbound.htm

			// First, reserve email capacity for the current Apex transaction to ensure
			// that we won't exceed our daily email limits when sending email after
			// the current transaction is committed.
			//Messaging.reserveSingleEmailCapacity(2);
/*
			// These methods available to all email message classes through the base Messaging.Email Base Class

			setBccSender(bcc)
			setReplyTo(replyAddress)
			setTemplateID(templateId)
			setSaveAsActivity(saveAsActivity)
			setSenderDisplayName(displayName)
			setUseSignature(useSignature)

			and through association:

			SaveAsTask 
*/
//			Mass Email Segment
			if (emailMessageType == 'massEmail'){
				//	setBccSender(bcc)
				//	setDescription(description)
				//	setReplyTo(replyAddress)
				//	setSaveAsActivity(saveAsActivity)
				//	setSenderDisplayName(displayName)
				//	setTargetObjectIds(targetObjectIds)
				//	setTemplateID(templateId)
				//	setUseSignature(useSignature)
				//	setWhatIds(whatIds)
				Messaging.MassEmailMessage mmail = new Messaging.MassEmailMessage();
				// Set to True if you want to BCC yourself on the email.
				mmail.setBccSender(bcc);
				//	setDescription(description)
				if (curRequest.description == null || curRequest.description.length() == 0){
					thisResponse.errors = 'You must specify a description for mass email message collections.';
				} else {
					mmail.description = curRequest.description;
				}
				//	setReplyTo(replyAddress)
				if (thisResponse.errors == null){
					mmail.setReplyTo(replyEmailAddress);
				}
				//	setSaveAsActivity(saveAsActivity)
				if (curRequest.setSaveAsActivity != NULL) mmail.setSaveAsActivity(curRequest.setSaveAsActivity);
				//	setSenderDisplayName(displayName)
				if (thisResponse.errors == null){
					mmail.setSenderDisplayName(senderDisplayName);
				}
				//	setTargetObjectIds(targetObjectIds)
				if (thisResponse.errors == null){
					if (curRequest.targetObjectIds == null || curRequest.targetObjectIds.size() == 0) {
						thisResponse.errors = 'You must specify a collection of targetObjectIds - required parameter for mass emails.';
					} else {
						mmail.setTargetObjectIds(curRequest.targetObjectIds);
						if (curRequest.whatIds != null && curRequest.whatIds.size() > 0 ){
							if (curRequest.whatIds.size() == curRequest.targetObjectIds.size()){
								try {
									mmail.setTargetObjectIds(curRequest.whatIds);
								} catch (Exception e){
									thisResponse.errors = e.getMessage();
								}
							}else{
								thisResponse.errors = 'You must match targetObjectIds one-for-one with whatIds';
							}
						}
					}
				}
				//	setTemplateID(templateId)
				if (thisResponse.errors == null){
					if (thisResponse.errors == null && (templateName != null && templateID != null)){
						thisResponse.errors = 'You\'re trying to pass in both the name of the template and a template ID. Gotta pick one or the other. Use templateName to select the first matching template qualified with \'Language="xxx_YY"\' in the Description.  The templateId represents a specific Salesforce Email Template (either Classic or Lightning).';
					}
					if (curRequest.TemplateID == null) {
						if (curRequest.templateName == null) {
							thisResponse.errors = 'You must specify a template name or Template ID - required parameter for mass emails.';
						} else {
							TemplateId = getTemplateIdFromName(templateName, null);
							if (TemplateId != null){
								mmail.setTemplateID(TemplateId);
							} else thisResponse.errors = 'An Email template with the specified template name could not be found';
						}
					} else {
						mmail.setTemplateID(curRequest.TemplateID);
					}
				}
				//	setUseSignature(useSignature)
				if (thisResponse.errors == null){
					mmail.setUseSignature(curRequest.useSalesforceSignature == NULL?false:curRequest.useSalesforceSignature);
				}
				if (thisResponse.errors == null) {
					mailMMList.add(mmail);
				} else thisResponse.isSuccess = false;
				responseList.add(thisResponse);
//			Single Email Segment
			} else {
				// Processes and actions involved in the SingleEmailMessage transaction occur next,
				// which conclude with sending a single email.

				// Strings to hold the email addresses to which you are sending the email.
				//String[] toAddresses = new String[] {oneAddress}; 
				Map<String, Object> m = GenerateMap(curRequest);
				curRequest.toAddresses = BuildAddressList('TO',m); 
				curRequest.ccAddresses = BuildAddressList('CC',m); 
				curRequest.bccAddresses = BuildAddressList('BCC', m);
				// Create a new single email message object
				// that will send out a single email to the addresses in the To, CC & BCC list.
				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
					
				// Assign the addresses for the To and CC lists to the mail object.
				mail.setToAddresses(curRequest.toAddresses);
				mail.setCcAddresses(curRequest.ccAddresses);
				mail.setBccAddresses(curRequest.bccAddresses);

				//outgoing email can either use an orgWideEmailAddress or specify it here, but not both
				if (orgWideEmailAddressId != null && orgWideEmailAddressId != '') {
					mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
				} else {
					// Specify the address used when the recipients reply to the email. 
					mail.setReplyTo(replyEmailAddress);

					// Specify the name used as the display name.
					mail.setSenderDisplayName(senderDisplayName);
				}

				// Specify the subject line for your email address.
				mail.setSubject(subject);

				// Set to True if you want to BCC yourself on the email.
				mail.setBccSender(bcc);

				// Optionally append the salesforce.com email signature to the email.
				// The email address of the user executing the Apex Code will be used.
				// True by default unless the user passes a value in.
				mail.setUseSignature(useSalesforceSignature);
				mail = AddAttachments(mail, curRequest.contentDocumentAttachments, null);
				
				if (thisResponse.errors == null && (templateName != null && templateID != null)){
					thisResponse.errors = 'You\'re trying to pass in both the name of the template and a template ID. Gotta pick one or the other. Use templateName to select the first matching template qualified with \'Language="xxx_YY"\' in the Description.  The templateId represents a specific Salesforce Email Template (either Classic or Lightning).';
				}

				if (thisResponse.errors == null && templateName != null){
					templateID = getTemplateIdFromName(templateName,templateLanguage);
					if (templateID == null){
						thisResponse.errors = 'Could not find email template named "'+templateName+'".  Please have your administrator check the name and/or accessibility of this template';
					}
					thisResponse.templateUsed = TemplateId;
				}

				if (thisResponse.errors == null && (templateID != null && ((HTMLbody != null) || (plainTextBody != null)))){
					thisResponse.errors = 'You\'re trying to pass in both a plaintext/html body and a template ID. Gotta pick one or the other. Make sure you\'re not confusing the Text Template resources in Flow, (which you can pass into either the HTMLBody or the plainTextBody) with the templateId, which represents a Salesforce Email Template (either Classic or Lightning).';
				}
				
				if (thisResponse.errors == null && (templateID == null  && HTMLbody == null && plainTextBody == null)){
					thisResponse.errors = 'Body text must be provided to Send Better Email Action, either via HTMLbody, plainTextBody, or a templateId';
				}
					
				if (thisResponse.errors == null && (curRequest.setSaveAsTask == true && recordId == null)){
					thisResponse.errors = 'In order to log this email send as a task, you need to pass in a recordId';
				}
				
				Boolean completed = true;
				String error;
				if (templateTargetObjectId != NULL) mail.setTargetObjectId(templateTargetObjectId);
				if (recordId != null) {
					mail.setWhatId(ID.valueOf(recordId));
				}

				// Specify the text content of the email.
				if (plainTextBody != NULL) mail.setPlainTextBody(plainTextBody);
				if (HTMLbody != NULL) mail.setHtmlBody(HTMLbody);
				if (curRequest.setSaveAsActivity != NULL) mail.setSaveAsActivity(curRequest.setSaveAsActivity);
				if (templateID != NULL){
					try {
						mail.setTemplateID(templateID);
						thisResponse.templateUsed = templateID;
					} catch (Exception e){
						thisResponse.errors = e.getMessage();
					}
				}
				if (thisResponse.errors == null) {
					mailList.add(mail);
				} else thisResponse.isSuccess = false;
				responseList.add(thisResponse);
			}
		}
		List<Messaging.SendEmailResult> emailResults = new List<Messaging.SendEmailResult>();
		if (mailMMList != NULL && mailMMList.size() > 0){
			try {
				emailResults = Messaging.sendEmail(mailMMList,false);
			} catch (Exception e){
				// if an error occurred in sendMail, put same error message on all responses
				for (Integer i=0; i < responseList.size();i++){
					if (requests[i].emailMessageType == 'massEmail'){
						responseList[i].isSuccess = false;
						responseList[i].errors = e.getmessage();
					}
				}
			}
			Integer replyPos = 0;
			for (Messaging.SendEmailResult thisResult : emailResults){
				while (responseList[replyPos].errors != null || requests[replyPos].emailMessageType != 'massEmail') replyPos++;
				if (thisResult.isSuccess() != true) {
					Messaging.SendEmailError[] curErrors = thisResult.getErrors();
					String errorReport = '';
					for(Messaging.SendEmailError curError : curErrors ) {
						errorReport = errorReport + 'Error Code: ' + curError.getStatusCode() + ' - '+ curError.getMessage() + '\n';
					}
					responseList[replyPos].errors = errorReport;
					responseList[replyPos].isSuccess = false;
				} else {
					responseList[replyPos].isSuccess = true;
					if (requests[replyPos].setSaveAsTask == true) {
						string subject = requests[replyPos].subject;
						if (requests[replyPos].templateID != null && subject == null){
							subject = [SELECT Subject FROM EmailTemplate WHERE Id=:requests[replyPos].templateID AND isActive = TRUE ].Subject;
						}
                        responseList[replyPos].taskIds = new List<String>();
						for (integer i=0;i<requests[replyPos].targetObjectIds.size();i++) {
							List<String> recipientList = new List<String>{	(String) Database.query('Select Email From ' +
							((Id)requests[replyPos].targetObjectIds[i]).getSObjectType().getDescribe().getName() + 
																		' Where Id = \''+ requests[replyPos].targetObjectIds[i] +
																		'\' limit 1')[0].get('Email')};
							TaskAttached thisTask = addTasksId(requests[replyPos].templateID,subject,
																		requests[replyPos].templateTargetObjectId, requests[replyPos].recordId,
																		recipientList,responseList[replyPos].errors);
							responseList[replyPos].errors = thisTask.errorMsg;
							responseList[replyPos].taskIds.add(thisTask.taskId);
						}
					}
				}
				replyPos++;
			}
		}
		if (mailList != NULL && mailList.size() > 0){
			try {
				emailResults = Messaging.sendEmail(mailList,false);
			} catch (Exception e){
				// if an error occurred in sendMail, put same error message on all responses
				for (Integer i=0; i < responseList.size();i++){
					if (requests[i].emailMessageType == 'massEmail'){
						responseList[i].isSuccess = false;
						responseList[i].errors = e.getmessage();
					}
				}
			}
			Integer replyPos = 0;
			for (Messaging.SendEmailResult thisResult : emailResults){
				while (responseList[replyPos].errors != null || requests[replyPos].emailMessageType == 'massEmail') replyPos++;
				if (thisResult.isSuccess() != true) {
					Messaging.SendEmailError[] curErrors = thisResult.getErrors();
					String errorReport = '';
					for(Messaging.SendEmailError curError : curErrors ) {
						errorReport = errorReport + 'Error Code:' + curError.getStatusCode() + ' - '+ curError.getMessage() + '\n';
					}
					responseList[replyPos].errors = errorReport;
					responseList[replyPos].isSuccess = false;
				} else {
					responseList[replyPos].isSuccess = true;
					if (requests[replyPos].setSaveAsTask == true) {
						List<String> recipientList = requests[replyPos].toAddresses;
						recipientList.addAll(requests[replyPos].ccAddresses);
						recipientList.addAll(requests[replyPos].bccAddresses);
						if (recipientList.size() == 0){
							requests[replyPos].toAddresses.add((String) (Database.query('Select Email From ' +
																				((Id)requests[replyPos].templateTargetObjectId).getSObjectType().getDescribe().getName() + 
																				' Where Id = \''+ requests[replyPos].templateTargetObjectId +'\' limit 1'))[0].get('Email'));
						}
						TaskAttached thisTask = addTasksId(requests[replyPos].templateID,requests[replyPos].subject,
																requests[replyPos].templateTargetObjectId, requests[replyPos].recordId,
																recipientList,responseList[replyPos].errors);
						responseList[replyPos].errors = thisTask.errorMsg;
                        responseList[replyPos].taskIds = new List<String>{thisTask.taskId};
					}
				}
				replyPos++;
			}
		}
		//report back the results
		boolean atLeastOneSent=false;
		for (Integer i=0;i<responseList.size();i++){
			if (responseList[i].isSuccess) atLeastOneSent = true;
		}
		if (!atLeastOneSent)
			throw new InvocableActionException('No Messages were sent.  First Error: '+responseList[0].errors);
		return responseList;
	}

	// Add a task activity    
	private static TaskAttached addTasksId(ID templateID, String subject, ID templateTargetObjectId, ID recordId, List<String> recipientList,String curErrors){
		TaskAttached retAttached = new TaskAttached();
		retAttached.errorMsg = curErrors;
		if (templateID != null && subject == null){
			subject = [SELECT Subject FROM EmailTemplate WHERE Id=:templateID AND isActive = TRUE ].Subject;
		}
		try {
			retAttached.taskId = createActivity(
				recordId,
				subject,
				recipientList
			);
		} catch (Exception e) {
			retAttached.errorMsg = ((curErrors != null) && (curErrors.length() > 0))? curErrors + ',' + e.getMessage() : e.getMessage();
		}
		return retAttached;
	}

	//credit to https://digitalflask.com/blog/send-email-attachments-salesforce-apex/
	public static Messaging.SingleEmailMessage AddAttachments(Messaging.SingleEmailMessage mail, List<ContentDocumentLink> contentDocumentLinks, String staticResourceNames) {
		List<SObject> curAttachments = new List<SObject>();
		if (staticResourceNames != null) {
			List<String> staticResourceNamesList = staticResourceNames.replaceAll('[^A-Z0-9]+//ig', ',').split(',');
			curAttachments.addAll([SELECT Id, Body, Name, ContentType FROM StaticResource WHERE Name IN:staticResourceNamesList]);
		}
 
		if (contentDocumentLinks != null && !contentDocumentLinks.isEmpty()) {
			Set<Id> cdIds = new Set<Id>();
			for (ContentDocumentLink cdl : contentDocumentLinks) {
				cdIds.add(cdl.ContentDocumentId);
			}

			for (ContentVersion cv : [SELECT Id, PathOnClient, VersionData, FileType FROM ContentVersion WHERE ContentDocumentId IN:cdIds]) {
				curAttachments.add(new StaticResource(Name = cv.PathOnClient, Body = cv.VersionData));
			}
		}

		List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();

		if (curAttachments != null) {
			for (SObject file : curAttachments) {
				Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
				efa.setFileName((String) file.get('Name'));
				efa.setBody((BLOB) file.get('Body'));
				efa.setContentType((String) file.get('ContentType'));
				attachments.add(efa);
			}
			mail.setFileAttachments(attachments);
		} 
		return mail;
	}

	public static String[] BuildAddressList(string type, Map<String, Object> m) {
		String[] addressList = new List<String>();
		String curEmail;

		//build address list
		//handle individual addresses
		String oneAddress = (String)m.get('Send' + type + 'thisOneEmailAddress');
		if ( oneAddress != null) {
			addressList.add(oneAddress);
		}

		//handle inputs involving collections of String addresses
		List<String> stringAddresses = (List<String>)m.get('Send' + type + 'thisStringCollectionOfEmailAddresses');
		if (stringAddresses != null) {
			addressList.addAll(stringAddresses);
		}
		//handle inputs involving collections of Contacts
		List<Contact> curContacts = (List<Contact>)m.get('Send' + type + 'theEmailAddressesFromThisCollectionOfContacts');        
		if (curContacts != null) {
			List<String> extractedEmailAddresses = new List<String>();
			for (Contact curContact : curContacts) {
				curEmail = curContact.email;
				if (curEmail != null) extractedEmailAddresses.add(curEmail);
			}
			addressList.addAll(extractedEmailAddresses);
		}
		
		//handle inputs involving collections of Users
		List<User> curUsers = (List<User>)m.get('Send' + type + 'theEmailAddressesFromThisCollectionOfUsers');
		if (curUsers != null) {
			List<String> extractedEmailAddresses = new List<String>();
			for (User curUser : curUsers) {
				curEmail = curUser.email;
				if (curEmail != null) extractedEmailAddresses.add(curEmail);
			}
			addressList.addAll(extractedEmailAddresses);
		}
		
		//handle inputs involving collections of Leads
		List<Lead> curLeads = (List<Lead>)m.get('Send' + type + 'theEmailAddressesFromThisCollectionOfLeads');
		if (curLeads != null) {
			List<String> extractedEmailAddresses = new List<String>();
			for (Lead curLead : curLeads) {
				curEmail = curLead.email;
				if (curEmail != null) extractedEmailAddresses.add(curEmail);
			}
			addressList.addAll(extractedEmailAddresses);
		}
		return addressList;
	}

	//this map makes it easier to efficiently use the same code to handle To, CC, and BCC.
	//by making the lookup a string, we can composite the string in the m.get lines above
	private static Map<String, Object> GenerateMap(Request request) {
	   
		return new Map<String, Object>{
		   'SendTOthisOneEmailAddress' => request.SendTOthisOneEmailAddress,
		   'SendTOthisStringCollectionOfEmailAddresses'  => request.SendTOthisStringCollectionOfEmailAddresses,
		   'SendTOtheEmailAddressesFromThisCollectionOfContacts' => request.SendTOtheEmailAddressesFromThisCollectionOfContacts,
		   'SendTOtheEmailAddressesFromThisCollectionOfUsers' => request.SendTOtheEmailAddressesFromThisCollectionOfUsers,
		   'SendTOtheEmailAddressesFromThisCollectionOfLeads' => request.SendTOtheEmailAddressesFromThisCollectionOfLeads,
		   'SendCCthisOneEmailAddress' => request.SendCCthisOneEmailAddress,
		   'SendCCthisStringCollectionOfEmailAddresses'  => request.SendCCthisStringCollectionOfEmailAddresses,
		   'SendCCtheEmailAddressesFromThisCollectionOfContacts' => request.SendCCtheEmailAddressesFromThisCollectionOfContacts,
		   'SendCCtheEmailAddressesFromThisCollectionOfUsers' => request.SendCCtheEmailAddressesFromThisCollectionOfUsers,
		   'SendCCtheEmailAddressesFromThisCollectionOfLeads' => request.SendCCtheEmailAddressesFromThisCollectionOfLeads,
		   'SendBCCthisOneEmailAddress' => request.SendBCCthisOneEmailAddress,
		   'SendBCCthisStringCollectionOfEmailAddresses'  => request.SendBCCthisStringCollectionOfEmailAddresses,
		   'SendBCCtheEmailAddressesFromThisCollectionOfContacts' => request.SendBCCtheEmailAddressesFromThisCollectionOfContacts,
		   'SendBCCtheEmailAddressesFromThisCollectionOfUsers' => request.SendBCCtheEmailAddressesFromThisCollectionOfUsers,
		   'SendBCCtheEmailAddressesFromThisCollectionOfLeads' => request.SendBCCtheEmailAddressesFromThisCollectionOfLeads 
		};
	}

	private static string createActivity(Id recordId, String subject, List<String> recipientList) {
		String recipientListString = string.join(recipientList,',');
		Task t = new Task(OwnerId = UserInfo.getUserId(),
				Subject = 'Sent Email: ' + subject,
				Description = 'Sent Email : ' + subject + ' to recipient(s): ' + recipientListString.replaceAll('[()]|,\\(\\)+', ''),
				Status = 'Closed',
				Priority = 'Normal',
				ActivityDate = Date.today(),
				WhatId = recordId);
		insert t;
		return t.Id;
	}

	private static String getTemplateIdFromName(String templateName, String templateLanguage){
		String retTemplateId;
		String blankTemplate;
		List<EmailTemplate> et = [SELECT Id,Description FROM EmailTemplate WHERE Name=:templateName AND isActive = TRUE];

		if (et.size() > 0){
			String localeKey = [Select LanguageLocaleKey From Organization Limit 1].LanguageLocaleKey;
			if (templateLanguage == NULL) templateLanguage = [Select LanguageLocaleKey From Organization limit 1].LanguageLocaleKey;
			for (EmailTemplate thisTemplate: et){
				if (thisTemplate.Description.Contains('Language="')){
					if (thisTemplate.Description.substringAfter('Language="').substringBefore('"') == templateLanguage){
						retTemplateID = thisTemplate.Id;
						break;
					}
				}else{
					blankTemplate = (blankTemplate == NULL) ? thisTemplate.Id : blankTemplate;
				}
			}
		}
		return (retTemplateId == NULL)? blankTemplate : retTemplateId;
	}

	private class TaskAttached {
		private String errorMsg;
		private String taskId;
	}

	public class Request {
		public String[] toAddresses; 
		public String[] ccAddresses; 
		public String[] bccAddresses;
		public Boolean setSaveAsActivity;
		public Boolean setSaveAsTask;

		@invocableVariable(label='bcc' description='Indicates whether the email sender receives a copy of the email that is sent. For a mass mail, the sender is only copied on the first email sent.')
		public Boolean bcc;

		@invocableVariable
		public List<ContentDocumentLink> contentDocumentAttachments;

		@invocableVariable(label='description' description='The description of the email used in results notification.')
		public String description;

		@invocableVariable(label='emailMessageType' description='\'singleEmail\'(default) or \'massEmail\'.  MassEmailMessage can send mails related to multiple records (WhatId and TargetObjectId), but is severely limited for other configuration purposes.')
		public String emailMessageType;

		@invocableVariable
		public String HTMLbody;

		@invocableVariable
		public String orgWideEmailAddressId;

		@invocableVariable
		public String plainTextBody;
		
		@invocableVariable(label='Related Record ID(whatId/recordId)' description='If you specify a contact for the targetObjectId field, you can specify an optional whatId as well. This helps to further ensure that merge fields in the template contain the correct data. This is used for merge fields and for associating activities and attachments.')
		public String recordId;

		@invocableVariable
		public String replyEmailAddress;
		
		@invocableVariable
		public String senderDisplayName;

		@invocableVariable
		public String SendTOthisOneEmailAddress;

		@invocableVariable
		public List<String> SendTOthisStringCollectionOfEmailAddresses;

		@invocableVariable
		public List<Contact> SendTOtheEmailAddressesFromThisCollectionOfContacts;

		@invocableVariable
		public List<User> SendTOtheEmailAddressesFromThisCollectionOfUsers;
		
		@invocableVariable
		public List<Lead> SendTOtheEmailAddressesFromThisCollectionOfLeads;

		@invocableVariable
		public String SendCCthisOneEmailAddress;

		@invocableVariable
		public List<String> SendCCthisStringCollectionOfEmailAddresses;

		@invocableVariable
		public List<Contact> SendCCtheEmailAddressesFromThisCollectionOfContacts;

		@invocableVariable
		public List<User> SendCCtheEmailAddressesFromThisCollectionOfUsers;
		
		@invocableVariable
		public List<Lead> SendCCtheEmailAddressesFromThisCollectionOfLeads;

		@invocableVariable
		public String SendBCCthisOneEmailAddress;

		@invocableVariable
		public List<String> SendBCCthisStringCollectionOfEmailAddresses;

		@invocableVariable
		public List<Contact> SendBCCtheEmailAddressesFromThisCollectionOfContacts;

		@invocableVariable
		public List<User> SendBCCtheEmailAddressesFromThisCollectionOfUsers;
		
		@invocableVariable
		public List<Lead> SendBCCtheEmailAddressesFromThisCollectionOfLeads;
		
		/*
			Static resources do not store file extensions, thus email attachments will have file names without extensions,
			which is inconvenient for an end user. Disabling this option for now.
			Possible workarounds:
			1. Specify full file name in Description of static resource
			2. Let the user pass file names together with static resource names
		 */
//        @invocableVariable
//        public String staticResourceAttachmentNames;

		@invocableVariable(description='Defaults to True')
		public Boolean saveAsActivity;

		@invocableVariable(description='Defaults to True unless recordId/whatId is null')
		public Boolean saveAsTask;

		@invocableVariable
		public String subject;
		
		@invocableVariable(label='targetObjectIds' description='A list of IDs of the contacts, leads, or users to which the email will be sent. The IDs you specify set the context and ensure that merge fields in the template contain the correct data. The objects must be of the same type (all contacts, all leads, or all users)')
		public List<String> targetObjectIds;
		
		@invocableVariable(label='templateID' )
		public String templateID;
		
		@invocableVariable(label='Template Language' description='Used in conjunction with Template Name, Finds templates with the name matching Template Name for \'Language="xxx_YY"\' in the Description.  Template Selection criteria order first found Name with: 1)If empty, Org LanguageLocaleKey 2)Language found in Description 3)First without \'Language="\'')
		public String templateLanguage;
		
		@invocableVariable(label='Template Name' description='Used in conjunction with Template Language. Finds templates with the name matching Template Name for \'Language="xxx_YY"\' in the Description.')
		public String templateName;
		
		@invocableVariable(label='Template Target Record Id' description='If you are passing in a template Id, you need to also pass in the Id of context record. It can be a Contact, Lead, or User. It will determine which data gets merged into the template')
		public String templateTargetObjectId;

		@invocableVariable(label='UseSalesforceSignature' description='True unless otherwise specified')
		public Boolean UseSalesforceSignature;

		@invocableVariable(label='whatIds' description='For MassEmail, if you specify a list of contacts for the targetObjectIds field, you can specify a list of whatIds as well. This helps to further ensure that merge fields in the template contain the correct data.')
		public List<String> whatIds;
}

	public class Response {
		@invocableVariable
		public Boolean isSuccess; 
		
		@invocableVariable
		public String templateUsed; 
		
		@invocableVariable
		public List<String> taskIds; 
		
		@invocableVariable
		public String errors;

	}

	public class InvocableActionException extends Exception {}
}