class SiteStatusSerializer < ActiveModel::Serializer
  attributes :campus_code, :name, :vac_status, :publish, :status, :course_open_date

  def campus_code
    object.site.code
  end

  def vac_status
    object.vac_status_before_type_cast
  end

  def status
    if object.no_vacancies?
      SiteStatus.statuses["suspended"]
    else
      object.status_before_type_cast
    end
  end

  def publish
    object.publish_before_type_cast
  end

  def course_open_date
    object.course.applications_open_from
  end

  def name
    object.site.location_name
  end
end
